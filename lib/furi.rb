require "cgi"
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
    URI.new(string)
  end

  class << self
    (PARTS + ALIASES.values.flatten + DELEGATES).each do |part|
      define_method(part) do |string|
        URI.new(string).send(part)
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

    (qs || '').split(/[&;] */n).each do |p|
      token = QueryToken.parse(p)
      normalize_params(params, token.name, token.value)
    end

    return params
  end

  def self.normalize_params(params, name, v)
    name =~ %r(\A[\[\]]*([^\[\]]+)\]*)
    k = $1 || ''
    after = $' || ''

    return if k.empty?

    if after == ""
      params[k] = v
    elsif after == "[]"
      params[k] ||= []
      raise TypeError, "expected Array (got #{params[k].class.name}) for param `#{k}'" unless params[k].is_a?(Array)
      params[k] << v
    elsif after =~ %r(^\[\]\[([^\[\]]+)\]$) || after =~ %r(^\[\](.+)$)
      child_key = $1
      params[k] ||= []
      raise TypeError, "expected Array (got #{params[k].class.name}) for param `#{k}'" unless params[k].is_a?(Array)
      if params_hash_type?(params[k].last) && !params[k].last.key?(child_key)
        normalize_params(params[k].last, child_key, v)
      else
        params[k] << normalize_params(params.class.new, child_key, v)
      end
    else
      params[k] ||= params.class.new
      raise TypeError, "expected Hash (got #{params[k].class.name}) for param `#{k}'" unless params_hash_type?(params[k])
      params[k] = normalize_params(params[k], after, v)
    end

    return params
  end

  def self.params_hash_type?(obj)
    obj.kind_of?(Hash)
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
      "#{CGI.escape(name.to_s)}=#{CGI.escape(value.to_s)}"
    end

    def inspect
      [name, value].join('=')
    end
  end

  class URI

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
        @protocol = nil if @protocol.empty?
      end
      if string.start_with?("//")
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

    def to_s
      result = []
      if protocol
        result << "#{protocol}://"
      end
      result << host
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
      @query = parse_query_tokens(@query_string)
    end

    def parse_query_tokens(string)
      Furi.parse_nested_query(string)
    end

    def query=(value)
      @query = nil
      case value
      when String then
        @query_string = value
      when Hash
        @query = value
      when nil
      else
        raise ArgumentError, 'Query can only be Hash or String'
      end
    end

    def query_string
      return @query_string unless query_level?
      Furi.serialize(@query)
    end

    def query_tokens
    end

    def expressions
      Furi.expressions
    end

    def port!
      return port if port
      return PORT_MAPPING[protocol] if protocol
      nil
    end

    protected

    def query_level?
      !!@query
    end
  end
end
