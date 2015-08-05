require "furi/version"
require "uri"

module Furi

  ESSENTIAL_PARTS =  [
    :anchor, :protocol, :query_tokens,
    :path, :host, :port, :username, :password
  ]
  COMBINED_PARTS = [
    :hostinfo, :userinfo, :authority, :ssl, :domain, :domain_name, 
    :domain_zone, :request
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
        Uri.new(string).send(part)
      end
    end
  end

  def self.update(string, parts)
    parse(string).update(parts).to_s
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

  def self.parse_nested_query(qs)

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
        case token
        when QueryToken
          token
        when String
          QueryToken.parse(token)
        when Array
          QueryToken.new(*token)
        else
          raise ArgumentError, "Can not parse query token #{token.inspect}"
        end
      end
    when nil, ''
      []
    when String
      query.gsub(/\A\?/, '').split(/[&;] */n).map do |p|
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
      k,v = token.split('=', 2).map { |s| ::URI.decode_www_form_component(s) }
      new(k,v)
    end

    def initialize(name, value)
      @name = name
      @value = value
    end

    def to_a
      [name, value]
    end

    def ==(other)
      to_s == other.to_s
    end

    def to_s
      "#{::URI.encode_www_form_component(name.to_s)}=#{::URI.encode_www_form_component(value.to_s)}"
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
          send(origin)
        end

        define_method(:"#{aliaz}=") do |*args|
          send(:"#{origin}=", *args)
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
        send(:"#{part}=", value)
      end
      self
    end

    def merge(parts)
      parts.each do |part, value|
        case part.to_sym
        when :query
          merge_query(value)
        else
          send(:"#{part}=", value)
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
      @host = host
    end

    def domain_zone
      parsed_host.last
    end

    def domain_name
      parsed_host[1]
    end

    def domain
      join_domain(parsed_host[1..2].flatten)
    end

    def subdomain
      parsed_host.first
    end

    def host_tokens
      host!.split(".")
    end

    def hostinfo
      return host unless explicit_port?
      [host, port].join(":")
    end

    def hostinfo=(string)
      host, port = string.split(":", 2)
      self.host = host if host
      self.port = port if port
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
      if protocol
        result.push(protocol.empty? ? "//" : "#{protocol}://")
      end
      result << authority
      result << (host ? path : path!)
      if query_tokens.any?
        result << "?" << query_string
      end
      if anchor
        result << "#" << anchor
      end
      result.join
    end
    
    def request
      result = []
      result << path!
      result << "?" << query_string if query_tokens.any?
      result.join
    end

    def request_uri
      request
    end

    def query
      return @query if query_level?
      @query = Furi.parse_nested_query(query_tokens)
    end


    def query=(value)
      @query = nil
      @query_tokens = []
      case value
      when String, Array
        self.query_tokens = value
      when Hash
        @query = value
        self.query_tokens = value
      when nil
      else
        raise ArgumentError, 'Query can only be Hash or String'
      end
    end

    def port=(port)
      if port != nil
        @port = port.to_i
        if @port == 0
          raise ArgumentError, "port should be an Integer > 0"
        end
      else
        @port = nil
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
      unless @path.start_with?("/")
        @path = "/" + @path
      end
    end

    def protocol=(protocol)
      @protocol = protocol ? protocol.gsub(%r{:/?/?\Z}, "") : nil
    end


    def query_string
      if query_level?
        Furi.serialize(@query)
      else
        query_tokens.join("&")
      end
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
    
    protected

    def query_level?
      !!@query
    end

    def explicit_port?
      port && port != default_port
    end

    def parse_uri_string(string)
      string, *anchor = string.split("#")
      self.anchor = anchor.join("#")
      if string.include?("?")
        string, query_string = string.split("?", 2)
        self.query_tokens = query_string
      end

      if string.include?("://")
        protocol, string = string.split(":", 2)
        self.protocol = protocol
      end
      if string.start_with?("//")
        self.protocol ||= ''
        string = string[2..-1]
      end

      if string.include?("/")
        string, path = string.split("/", 2)
        self.path = path
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

    def parsed_host
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
      [join_domain(subdomain), domainname, join_domain(zone)]
    end

    def join_domain(tokens)
      tokens.any? ? tokens.join(".") : nil
    end

  end

  class FormattingError < StandardError
  end

  class Utils
    class << self
      def stringify_keys(hash)
        result = {}
        hash.each_key do |key|
          result[key.to_s] = hash[key]
        end
        result
      end
    end
  end
end
