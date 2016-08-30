module Furi
  class Uri

    attr_reader(*Furi::ESSENTIAL_PARTS)

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

    def initialize(argument)
      @query_tokens = []
      case argument
      when String
        parse_uri_string(argument)
      when Hash
        replace(argument)
      when ::URI::Generic
        parse_uri_string(argument.to_s)
      else
        raise ArgumentError, "wrong Uri argument"
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
        self.query = self.query.merge(Furi::Utils.stringify_keys(query))
      when String, Array
        self.query_tokens += Furi.query_tokens(query)
      when nil
      else
        raise ArgumentError, "#{query.inspect} can not be merged"
      end
    end

    def userinfo
      if username
        [username, password].compact.join(":")
      elsif password
        raise Furi::FormattingError, "can not build URI with password but without username"
      else
        nil
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
      return host unless explicit_port?
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

    def to_s
      result = []
      result << location
      result << (host ? path : path!)
      if query_tokens.any?
        result << "?" << query_string
      end
      if anchor
        result << "#" << anchor
      end
      result.join
    end

    def location
      if protocol
        unless host
          raise Furi::FormattingError, "can not build URI with protocol but without host"
        end
        [protocol.empty? ? "" : "#{protocol}:", authority].join("//")
      else
        authority
      end
    end

    def location=(string)
      string ||= ""
      string  = string.gsub(%r(/\Z), '')
      self.protocol = nil
      string = parse_protocol(string)
      self.authority = string
    end

    def request
      result = []
      result << path!
      result << "?" << query_string if query_tokens.any?
      result.join
    end

    def request=(string)
      string = parse_anchor_and_query(string)
      self.path = string
    end

    def home_page?
      path! == Furi::ROOT || path! == "/index.html"
    end

    def query
      return @query if query_level?
      @query = Furi.parse_query(query_tokens)
    end


    def query=(value)
      case value
      when true
        # Assuming that current query needs to be parsed to Hash
        query
      when String, Array
        self.query_tokens = value
        @query = nil
      when Hash
        self.query_tokens = value
        @query = value
      when nil
      else
        raise ArgumentError, 'Query can only be Hash or String'
      end
    end

    def port=(port)
      @port = case port
              when String
                if port.empty?
                  nil
                else
                  unless port =~ /\A\s*\d+\s*\z/
                    raise ArgumentError, "port should be an Integer >= 0"
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
      @query = nil
      @query_tokens = Furi.query_tokens(tokens)
    end

    def username=(username)
      @username = username.nil? ? nil : username.to_s
    end

    def password=(password)
      @password = password.nil? ? nil : password.to_s
    end

    def userinfo=(userinfo)
      username, password = (userinfo || "").split(":", 2)
      self.username = username
      self.password = password
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


    def directory
      path_tokens[0..-2].join("/")
    end

    def directory=(string)
      string ||= "/"
      if filename && string !~ %r{/\z}
        string += '/'
      end
      self.path = string + filename.to_s
    end

    def extension
      return nil unless filename
      file_tokens.size > 1 ? file_tokens.last : nil
    end

    def extension=(string)
      tokens = file_tokens
      case tokens.size
      when 0
        raise Furi::FormattingError, "can not assign extension when there is no filename"
      when 1
        tokens.push(string)
      else
        if string
          tokens[-1] = string
        else
          tokens.pop
        end
      end
      self.filename = tokens.join(".")
    end

    def filename=(name)
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


    def query_string
      if query_level?
        Furi.serialize(query)
      else
        query_tokens.any? ? query_tokens.join("&") : nil
      end
    end

    def query_string!
      query_string || ""
    end

    def query_string=(string)
      self.query_tokens = string.to_s
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

    def filename
      result = path_tokens.last
      result == "" ? nil : result
    end

    def filename!
      filename || ''
    end

    def default_web_port?
      Furi::WEB_PROTOCOL.any? do |web_protocol|
        Furi::PROTOCOLS[web_protocol][:port] == port!
      end
    end

    def web_protocol?
      Furi::WEB_PROTOCOL.include?(protocol)
    end

    def resource
      [request, anchor].compact.join("#")
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
      [request]
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

    def rfc3986?
      uri = to_s
      !!(uri.match(URI::RFC3986_Parser::RFC3986_Parser) ||
         uri.match(URI::RFC3986_Parser::RFC3986_relative_ref))
    end

    protected

    def file_tokens
      filename ? filename.split('.') : []
    end

    def query_level?
      !!@query
    end

    def explicit_port?
      port && port != default_port
    end

    def parse_uri_string(string)
      string = parse_anchor_and_query(string)

      string = parse_protocol(string)

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
      self.anchor = anchor.join("#")
      if string && string.include?("?")
        string, query_string = string.split("?", 2)
        self.query_tokens = query_string
      end
      string
    end

    def join(uri)
      Uri.new(::URI.join(to_s, uri.to_s))
    end

    def parse_protocol(string)
      if string.include?("://")
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
  end
end
