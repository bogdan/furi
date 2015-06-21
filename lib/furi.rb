require "furi/version"
require "uri"

module Furi

  PARTS =  [
    :anchor, :protocol, :query_string,
    :path, :host, :port, :username, :password
  ]
  ALIASES = {
    protocol: [:schema],
    anchor: [:fragment],
  }

  DELEGATES = [:port!]

  PORT_MAPPING = {
    "http" => 80,
    "https" => 443,
    "ftp" => 21,
    "tftp" => 69,
    "sftp" => 22,
    "ssh" => 22,
    "svn+ssh" => 22,
    "telnet" => 23,
    "nntp" => 119,
    "gopher" => 70,
    "wais" => 210,
    "ldap" => 389,
    "prospero" => 1525
  }

  class Expressions
    attr_accessor :protocol

    def initialize
      @protocol = /^[a-z][a-z0-9.+-]*$/i
    end
  end

  def self.expressions
    Expressions.new
  end

  def self.parse(string)
    Uri.new(string)
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
    if query.is_a?(Array)
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
    else
      (query || '').split(/[&;] */n).map do |p|
        QueryToken.parse(p)
      end
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

  def self.serialize(string, namespace = nil)
    serialize_tokens(string, namespace).join("&")
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

    def to_s
      "#{::URI.encode_www_form_component(name.to_s)}=#{::URI.encode_www_form_component(value.to_s)}"
    end

    def inspect
      [name, value].join('=')
    end
  end

  class Uri

    attr_reader(*PARTS)

    ALIASES.each do |origin, aliases|
      aliases.each do |aliaz|
        define_method(aliaz) do
          send(origin)
        end
      end
    end

    def initialize(string)
      string, *@anchor = string.split("#")
      @anchor = @anchor.empty? ? nil : @anchor.join("#")
      if string.include?("?")
        string, query_string = string.split("?", 2)
        @query_string = query_string
      end

      if string.include?("://")
        @protocol, string = string.split(":", 2)
        @protocol = '' if @protocol.empty?
      end
      if string.start_with?("//")
        @protocol ||= ''
        string = string[2..-1]
      end
      parse_authority(string)
    end

    def update(parts)
      parts.each do |part, value|
        send(:"#{part}=", value)
      end
      self
    end

    def merge(parts)
      parts.each do |part, value|
        
      end
    end

    def to_s
      result = []
      if protocol
        result.push(protocol.empty? ? "//" : "#{protocol}://")
      end
      result << host
      if port && !default_port?
        result << ":#{port}"
      end
      result << path
      if query_string
        result << "?"
        result << query_string
      end
      if anchor
        result << "#"
        result << anchor
      end
      result.join
    end

    def parse_authority(string)
      if string.include?("/")
        string, @path = string.split("/", 2)
        @path = "/" + @path
      end

      if string.include?("@")
        userinfo, string = string.split("@", 2)
        @username, @password = userinfo.split(":", 2)
      end
      if string.include?(":")
        string, @port = string.split(":", 2)
        @port = @port.to_i
      end
      if string.empty?
        @host = nil
      else
        @host = string
      end
    end

    def query
      return @query if query_level?
      @query = Furi.parse_nested_query(@query_string)
    end


    def query=(value)
      @query = nil
      case value
      when String
        @query_string = value
      when Array
        @query = Furi.query_tokens(value)
      when Hash
        @query = value
      when nil
      else
        raise ArgumentError, 'Query can only be Hash or String'
      end
    end

    def host=(host)
      @host = host
    end

    def port=(port)
      @port = port.to_i
      if @port == 0
        raise ArgumentError, "port should be an Integer > 0"
      end
      @port
    end

    def protocol=(protocol)
      @protocol = protocol ? protocol.gsub(%r{:/?/?\Z}, "") : nil
    end

    def query_string
      return @query_string unless query_level?
      Furi.serialize(@query)
    end

    def expressions
      Furi.expressions
    end

    def port!
      port || default_port
    end

    def default_port
      protocol ? PORT_MAPPING[protocol] : nil
    end
    
    def default_port?
      default_port && port == default_port
    end

    protected

    def query_level?
      !!@query
    end
  end
end
