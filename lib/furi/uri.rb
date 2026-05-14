require 'pathname'

module Furi
  class Uri

    attr_reader(*(Furi::ESSENTIAL_PARTS - [:query_string]))

    def query_string(escape_query_param: nil)
      if escape_query_param
        tokens = query_tokens
        return nil if tokens.empty?
        tokens.map { |t| escape_query_param.call(t.name, t.value) || t.to_s }.join("&")
      elsif @query
        s = Furi.serialize(@query)
        s.empty? ? nil : s
      elsif @query_string
        @query_string
      elsif @query_tokens&.any?
        @query_tokens.join("&")
      end
    end

    def query_tokens
      if @query_tokens
        @query_tokens
      elsif @query
        Furi.send(:serialize_tokens, @query)
      elsif @query_string
        @query_tokens = Furi.query_tokens(@query_string)
      else
        []
      end
    end

    Furi::ALIASES.each do |origin, aliases|
      aliases.each do |aliaz|
        define_method(aliaz) do
          self[origin]
        end

        define_method(:"#{aliaz}=") do |arg|
          self[origin] = arg
        end
      end
    end

    def initialize(argument, priority: :host)
      @query_tokens = nil
      @query_string = nil
      @priority = priority
      case argument
      when String
        parse_uri_string(argument)
      when Hash
        replace(argument)
      when ::URI::Generic
        parse_uri_string(argument.to_s)
      else
        raise ParseError, "wrong Uri argument"
      end
    end

    def replace(parts)
      if parts
        parts.each do |part, value|
          self[part] = value
        end
      end
      self
    end

    def update(parts)
      return self unless parts
      parts.each do |part, value|
        case part.to_sym
        when :query, :query_tokens, :query_string
          merge_query(value)
        when :path
          if value && self[part]
            self[part] = Pathname.new(self[part]).join(value).to_s
          else
            self[part] = value
          end
        else
          self[part] = value
        end
      end
      self
    end

    def defaults(parts)
      parts.each do |part, value|
        case part.to_sym
        when :query, :query_tokens
          Furi.parse_query(value).each do |key, default_value|
            unless query.key?(key)
              query[key] = default_value
            end
          end
        else
          unless self[part]
            self[part] = value
          end
        end
      end
      self
    end

    def merge_query(query)
      case query
      when Hash
        self.query = Furi::Utils.deep_merge(
          self.query,
          Furi::Utils.stringify_keys(query)
        )
      when String, Array
        self.query_tokens += Furi.query_tokens(query)
      when nil
      else
        raise QueryParseError, "#{query.inspect} can not be merged"
      end
    end

    def userinfo
      if username
        result = URI.encode_www_form_component(username)
        result += ":#{URI.encode_www_form_component(password)}" if password
        result
      elsif password
        raise Furi::FormattingError, "can not build URI with password but without username"
      end
    end

    def host=(host)
      @host = case host
              when Array
                join_domain(host)
              when "", nil
                nil
              else
                host.to_s.downcase
              end
    end

    def domainzone
      parsed_host.last
    end

    def domainzone=(new_zone)
      self.host = [subdomain, domainname, new_zone]
    end

    def domainname
      parsed_host[1]
    end

    def domainname=(new_domainname)
      self.domain = join_domain([subdomain, new_domainname, domainzone])
    end

    def domain
      join_domain(parsed_host[1..2].flatten)
    end

    def domain=(new_domain)
      self.host= [subdomain, new_domain]
    end

    def subdomain
      parsed_host.first
    end

    def subdomain=(new_subdomain)
      self.host = [new_subdomain, domain]
    end

    def hostinfo
      return host unless custom_port?
      if port && !host
        raise Furi::FormattingError, "can not build URI with port but without host"
      end
      [host, port].join(":")
    end

    def hostinfo=(string)
      if string.match(%r{\A\[.+\]\z}) #ipv6 host
        self.host = string
      else
        if match = string.match(/\A(.+):(.*)\z/)
          self.host, self.port = match.captures
        else
          self.host = string
          self.port = nil
        end
      end
    end

    def authority
      return hostinfo unless userinfo
      [userinfo, hostinfo].join("@")
    end

    def authority=(string)
      if string.include?("@")
        userinfo, string = string.split("@", 2)
        self.userinfo = userinfo
      else
        self.userinfo = nil
      end
      self.hostinfo = string
    end

    def to_s(escape_query_param: nil)
      result = []
      result << location
      result << (host || mailto? ? path : path!)
      if (qs = query_string(escape_query_param: escape_query_param))
        result << "?" << qs
      end
      if anchor
        result << encoded_anchor
      end
      result.join
    end

    def location
      if protocol
        if !host && !mailto?
          raise Furi::FormattingError, "can not build URI with protocol but without host"
        end
        [
          protocol.empty? ? "" : "#{protocol}:", authority
        ].join(mailto? ? "" : "//")
      else
        authority
      end
    end

    def endpoint
      [location, path].join
    end

    def endpoint=(string)
      string ||= ""
      string = parse_protocol(string)
      authority, path = string.split("/", 2)
      self.authority = authority
      self.path = path ? "/#{path}" : nil
    end

    def location=(string)
      string ||= ""
      string  = string.gsub(%r(/\Z), '')
      self.protocol = nil
      string = parse_protocol(string)
      self.authority = string
    end

    def request
      return nil if !path && query_tokens.empty?
      result = []
      result << path!
      result << "?" << query_string if query_tokens.any?
      result.join
    end

    def request!
      request || path!
    end

    def request=(string)
      string = parse_anchor_and_query(string)
      self.path = string
    end

    def home_page?
      path! == Furi::ROOT || path! == "/index.html"
    end

    def query
      @query ||= Furi.parse_query(query_tokens)
    end

    def query=(value)
      case value
      when true
        @query ||= Furi.parse_query(query_tokens)
        @query_string = nil
        @query_tokens = nil
      when String, Array
        self.query_tokens = value
      when Hash
        self.query_tokens = value
      when nil
      else
        raise QueryParseError, 'Query can only be Hash or String'
      end
    end

    def port=(port)
      @port = case port
              when String
                if port.empty?
                  nil
                else
                  unless port =~ /\A\s*\d+\s*\z/
                    raise Furi::ParseError, "port should be an Integer >= 0, got: #{port.inspect}"
                  end
                  port.to_i
                end
              when Integer
                if port < 0
                  raise ArgumentError, "port should be an Integer >= 0"
                end
                port
              when nil
                nil
              else
                raise ArgumentError, "can not parse port: #{port.inspect}"
              end
      @port
    end

    def query_tokens=(tokens)
      if tokens.is_a?(Hash)
        @query = tokens
        @query_tokens = nil
      else
        @query = nil
        @query_tokens = Furi.query_tokens(tokens)
      end
      @query_string = nil
    end

    def username=(username)
      @username = username.nil? ? nil : username.to_s
    end

    def password=(password)
      @password = password.nil? ? nil : password.to_s
    end

    def userinfo=(userinfo)
      parser = defined?(::URI::RFC2396_PARSER) ? ::URI::RFC2396_PARSER : ::URI::DEFAULT_PARSER
      username, password = (userinfo || "").split(":", 2)
      self.username = username ? parser.unescape(username) : nil
      self.password = password ? parser.unescape(password) : nil
    end

    def path=(path)
      @path = path.to_s
      if !@path.empty? && !@path.start_with?("/")
        @path = "/" + @path
      end
    end

    def protocol=(protocol)
      @protocol = protocol ? protocol.gsub(%r{:?/?/?\Z}, "").downcase : nil
    end

    def protocol!
      protocol || default_protocol_for_port || 'http' # Web Rules Them All!
    end

    def directory
      path_tokens[0..-2].join("/")
    end

    def directory=(string)
      string ||= "/"
      if file && string !~ %r{/\z}
        string += '/'
      end
      self.path = string + file.to_s
    end

    def filename
      return nil unless file
      file_tokens.first
    end

    def filename=(value)
      t = file_tokens
      t[0] = value
      self.file = t.join(".")
    end

    def extension
      return nil unless file
      tokens = file_tokens[1..-1]
      tokens.any? ? tokens.join(".") : nil
    end

    def extension=(string)
      tokens = file_tokens
      case tokens.size
      when 0
        raise Furi::FormattingError, "can not assign extension when there is no file"
      when 1
        tokens.push(string)
      else
        if string
          tokens = [tokens.first, string]
        else
          tokens.pop
        end
      end
      self.file = tokens.join(".")
    end

    def file=(name)
      unless name
        return unless path
      else
        name = name.gsub(%r{\A/}, "")
      end

      self.path = path_tokens.tap do |p|
        filename_index = [p.size-1, 0].max
        p[filename_index] = name
      end.join("/")
    end

    def path_tokens
      return [] unless path
      path.split("/", -1)
    end


    def query_string!
      query_string || ""
    end

    def query_string=(string)
      @query_string = string.nil? || string.empty? ? nil : string
      @query_tokens = nil
      @query = nil
    end

    def port!
      port || default_port
    end

    def default_port
      Furi::PROTOCOLS.fetch(protocol, {})[:port]
    end

    def ssl?
      !!(Furi::PROTOCOLS.fetch(protocol, {})[:ssl])
    end

    def ssl
      ssl?
    end

    def ssl=(ssl)
      self.protocol = find_protocol_for_ssl(ssl)
    end

    def file
      result = path_tokens.last
      result == "" ? nil : result
    end

    def file!
      file || ''
    end

    def default_web_port?
      Furi::WEB_PROTOCOL.any? do |web_protocol|
        Furi::PROTOCOLS[web_protocol][:port] == port!
      end
    end

    def web_protocol?
      Furi::WEB_PROTOCOL.include?(protocol)
    end

    def https?
      protocol == "https"
    end

    def http?
      protocol == "http"
    end

    def relative?
      !protocol
    end

    def abstract_protocol?
      protocol == ""
    end

    def resource
      return nil unless request
      request + encoded_anchor
    end

    def resource=(value)
      self.anchor = nil
      self.query_tokens = []
      self.path = nil
      value = parse_anchor_and_query(value)
      self.path = value
    end

    def path!
      path || Furi::ROOT
    end

    def resource!
      resource || request!
    end

    def host!
      host || ""
    end

    def ==(other)
      to_s == other.to_s
    end

    def inspect
      "#<#{self.class} #{to_s.inspect}>"
    end

    def anchor=(string)
      string = string.to_s
      @anchor = string.empty? ? nil : string
    end

    def [](part)
      send(part)
    end

    def []=(part, value)
      send(:"#{part}=", value)
    end

    def rfc?
      rfc3986?
    end

    def rfc3986?
      uri = to_s
      !!(uri.match(URI::RFC3986_Parser::RFC3986_URI) ||
         uri.match(URI::RFC3986_Parser::RFC3986_relative_ref))
    end

    def email=(email)
      self.protocol ||= "mailto"
      self.authority = email
    end

    def email
      authority
    end

    def custom_port?
      port && port != default_port
    end

    def mailto?
      protocol == "mailto"
    end

    FRAGMENT_UNSAFE = /[^a-zA-Z0-9\-\._~!$&'()*+,;=:@\/?]/.freeze

    protected

    def file_tokens
      file ? file.split('.') : []
    end


    def parse_uri_string(string)
      if string.empty?
        raise Furi::FormattingError, "can not be an empty string"
      end
      string = parse_anchor_and_query(string)

      string = parse_protocol(string)

      if protocol.nil? && @priority == :path
        self.path = string.start_with?("/") ? string : "/#{string}"
        return
      end

      if string.include?("/")
        string, path = string.split("/", 2)
        self.path = "/" + path
      end

      self.authority = string
    end

    def find_protocol_for_ssl(ssl)
      if Furi::SSL_MAPPING.key?(protocol)
        ssl ? Furi::SSL_MAPPING[protocol] : protocol
      elsif Furi::SSL_MAPPING.values.include?(protocol)
        ssl ? protocol : Furi::SSL_MAPPING.invert[protocol]
      else
        raise ArgumentError, "Can not specify SSL for #{protocol.inspect} protocol"
      end
    end

    def join_domain(tokens)
      tokens = tokens.compact
      tokens.any? ? tokens.join(".") : nil
    end

    def parse_anchor_and_query(string)
      string ||= ''
      string, *anchor = string.split("#")
      parser = defined?(::URI::RFC2396_PARSER) ? ::URI::RFC2396_PARSER : ::URI::DEFAULT_PARSER
      self.anchor = parser.unescape(anchor.join("#"))
      if string && string.include?("?")
        string, query_string = string.split("?", 2)
        self.query_string = query_string
      end
      string
    end

    def join(uri)
      Uri.new(::URI.join(to_s, uri.to_s))
    end

    def parse_protocol(string)
      if string.include?("://") || string.start_with?("mailto:")
        protocol, string = string.split(":", 2)
        self.protocol = protocol
      end
      if string.start_with?("//")
        self.protocol ||= ''
        string = string[2..-1]
      end
      string
    end

    def parsed_host
      return @parsed_host if @parsed_host
      tokens = host_tokens
      zone = []
      subdomain = []
      while tokens.any? && tokens.last.size <= 3 && tokens.size >= 2
        zone.unshift tokens.pop
      end
      while tokens.size > 1
        subdomain << tokens.shift
      end
      domainname = tokens.first
      @parsed_host = [join_domain(subdomain), domainname, join_domain(zone)]
    end

    def host_tokens
      host.split(".")
    end

    def default_protocol_for_port
      return nil unless port
      PROTOCOLS.each do |protocol, data|
        if data[:port] == port
          return protocol
        end
      end
    end

    def encoded_anchor
      return "" unless anchor
      "#" + anchor.gsub(FRAGMENT_UNSAFE) { |c| c.bytes.map { |b| "%%%02X" % b }.join }
    end
  end
end
