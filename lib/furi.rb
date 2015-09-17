require "furi/version"
require "uri"

module Furi

  ESSENTIAL_PARTS =  [
    :anchor, :protocol, :query_tokens,
    :path, :host, :port, :username, :password
  ]
  COMBINED_PARTS = [
    :hostinfo, :userinfo, :authority, :ssl, :domain, :domainname, 
    :domainzone, :request, :location, :query
  ]
  PARTS = ESSENTIAL_PARTS + COMBINED_PARTS

  ALIASES = {
    protocol: [:schema, :scheme],
    anchor: [:fragment],
    host: [:hostname],
    username: [:user],
    request: [:request_uri]
  }

  DELEGATES = [:port!, :host!, :path!]

  PROTOCOLS = {
    "http" => {port: 80, ssl: false},
    "https" => {port: 443, ssl: true},
    "ftp" => {port: 21},
    "tftp" => {port: 69},
    "sftp" => {port: 22},
    "ssh" => {port: 22, ssl: true},
    "svn+ssh" => {port: 22, ssl: true},
    "telnet" => {port: 23},
    "nntp" => {port: 119},
    "gopher" => {port: 70},
    "wais" => {port: 210},
    "ldap" => {port: 389},
    "prospero" => {port: 1525},
  }


  SSL_MAPPING = {
    'http' => 'https',
    'ftp' => 'sftp',
    'svn' => 'svn+ssh',
  }

  WEB_PROTOCOL = ['http', 'https']

  ROOT = '/'

  class Expressions
    attr_accessor :protocol

    def initialize
      @protocol = /^[a-z][a-z0-9.+-]*$/i
    end
  end

  def self.expressions
    Expressions.new
  end

  def self.parse(argument)
    Uri.new(argument)
  end

  def self.build(argument)
    Uri.new(argument).to_s
  end

  class << self
    (PARTS + ALIASES.values.flatten + DELEGATES).each do |part|
      define_method(part) do |string|
        Uri.new(string)[part]
      end
    end
  end

  def self.update(string, parts)
    parse(string).update(parts).to_s
  end

  def self.defaults(string, parts)
    parse(string).defaults(parts).to_s
  end

  def self.merge(string, parts)
    parse(string).merge(parts).to_s
  end

  def self.serialize_tokens(query, namespace = nil)
    case query
    when Hash
      result = query.map do |key, value|
        unless (value.is_a?(Hash) || value.is_a?(Array)) && value.empty?
          serialize_tokens(value, namespace ? "#{namespace}[#{key}]" : key)
        else
          nil
        end
      end
      result.flatten!
      result.compact!
      result
    when Array
      if namespace.nil? || namespace.empty?
        raise ArgumentError, "Can not serialize Array without namespace"
      end

      namespace = "#{namespace}[]"
      query.map do |item|
        if item.is_a?(Array)
          raise ArgumentError, "Can not serialize #{item.inspect} as element of an Array"
        end
        serialize_tokens(item, namespace)
      end
    else
      if namespace
        QueryToken.new(namespace, query)
      else
        []
      end
    end
  end

  def self.parse_query(qs)
    return Furi::Utils.stringify_keys(qs) if qs.is_a?(Hash)

    params = {}
    query_tokens(qs).each do |token|
      parse_query_token(params, token.name, token.value)
    end

    return params
  end

  def self.query_tokens(query)
    case query
    when Enumerable, Enumerator
      query.map do |token|
        QueryToken.parse(token)
      end
    when nil, ''
      []
    when String
      query.gsub(/\A\?/, '').split(/[&;] */n, -1).map do |p|
        QueryToken.parse(p)
      end
    else
      raise ArgumentError, "Can not parse #{query.inspect} query tokens"
    end
  end

  def self.parse_query_token(params, name, value)
    name =~ %r(\A[\[\]]*([^\[\]]+)\]*)
    namespace = $1 || ''
    after = $' || ''

    return if namespace.empty?

    current = params[namespace]
    if after == ""
      current = value
    elsif after == "[]"
      current ||= []
      unless current.is_a?(Array)
        raise TypeError, "expected Array (got #{current.class}) for param `#{namespace}'"
      end
      current << value
    elsif after =~ %r(^\[\]\[([^\[\]]+)\]$) || after =~ %r(^\[\](.+)$)
      child_key = $1
      current ||= []
      unless current.is_a?(Array)
        raise TypeError, "expected Array (got #{current.class}) for param `#{namespace}'"
      end
      if current.last.is_a?(Hash) && !current.last.key?(child_key)
        parse_query_token(current.last, child_key, value)
      else
        current << parse_query_token({}, child_key, value)
      end
    else
      current ||= {}
      unless current.is_a?(Hash)
        raise TypeError, "expected Hash (got #{current.class}) for param `#{namespace}'"
      end
      current = parse_query_token(current, after, value)
    end
    params[namespace] = current

    return params
  end

  def self.serialize(query, namespace = nil)
    serialize_tokens(query, namespace).join("&")
  end

  class QueryToken
    attr_reader :name, :value

    def self.parse(token)
      case token
      when QueryToken
        token
      when String
        key, value = token.split('=', 2).map do |s|
          ::URI.decode_www_form_component(s)
        end
        key ||= ""
        new(key, value)
      when Array
        QueryToken.new(*token)
      else
        raise_parse_error(token)
      end
    end

    def self.raise_parse_error(token)
      raise ArgumentError, "Can not parse query token #{token.inspect}"
    end

    def initialize(name, value)
      @name = name
      @value = value
    end

    def to_a
      [name, value]
    end

    def ==(other)
      other = self.class.parse(other)
      return false unless other
      to_s == other.to_s
    end

    def to_s
      encoded_key = ::URI.encode_www_form_component(name.to_s)
      
      encoded_key ? 
        "#{encoded_key}=#{::URI.encode_www_form_component(value.to_s)}" :
        encoded_key
    end

    def as_json
      to_a
    end

    def inspect
      [name, value].join('=')
    end
  end

  class Uri

    attr_reader(*ESSENTIAL_PARTS)

    ALIASES.each do |origin, aliases|
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
        update(argument)
      end
    end

    def update(parts)
      parts.each do |part, value|
        self[part] = value
      end
      self
    end

    def merge(parts)
      parts.each do |part, value|
        case part.to_sym
        when :query, :query_tokens
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
        raise FormattingError, "can not build URI with password but without username"
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
                host.to_s
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
        raise FormattingError, "can not build URI with port but without host"
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
          raise FormattingError, "can not build URI with protocol but without host"
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

    def query
      return @query if query_level?
      @query = Furi.parse_query(query_tokens)
    end


    def query=(value)
      @query = nil
      @query_tokens = []
      case value
      when String, Array
        self.query_tokens = value
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
      @protocol = protocol ? protocol.gsub(%r{:?/?/?\Z}, "") : nil
    end

    def filename
      path_tokens.last
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

    def expressions
      Furi.expressions
    end

    def port!
      port || default_port
    end

    def default_port
      protocol && PROTOCOLS[protocol] ? PROTOCOLS[protocol][:port] : nil
    end

    def ssl?
      !!(protocol && PROTOCOLS[protocol][:ssl])
    end

    def ssl
      ssl?
    end

    def ssl=(ssl)
      self.protocol = find_protocol_for_ssl(ssl)
    end

    def filename
      path.split("/").last
    end

    def default_web_port?
      WEB_PROTOCOL.any? do |web_protocol|
        PROTOCOLS[web_protocol][:port] == port!
      end
    end

    def web_protocol?
      WEB_PROTOCOL.include?(protocol)
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
      path || ROOT
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
    
    protected

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
      if SSL_MAPPING.key?(protocol)
        ssl ? SSL_MAPPING[protocol] : protocol
      elsif SSL_MAPPING.values.include?(protocol)
        ssl ? protocol : SSL_MAPPING.invert[protocol]
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

  class FormattingError < StandardError
  end

  class Utils
    class << self
      def stringify_keys(hash)
        result = {}
        hash.each_key do |key|
          value = hash[key]
          result[key.to_s] = value.is_a?(Hash) ? stringify_keys(value) : value
        end
        result
      end
    end
  end
 
  class HostName

    attr_reader :name

    def initialize(name)
      @name = name
    end

    def inspect
      to_s.inspect
    end

    def ==(other)
      to_s == other.to_s
    end

    def subdomain
      parsed_host[0]
    end

    def domainname
      parsed_host[1]
    end

    def domainzone
      parsed_host[2]
    end

    def to_s
      if @parsed_host
        join_domain(@parsed_host)
      else
        @name
      end
    end

  end
end
