require "furi/version"
require "uri"

module Furi

  autoload :QueryToken, 'furi/query_token'
  autoload :Uri, 'furi/uri'
  autoload :Utils, 'furi/utils'

  ESSENTIAL_PARTS =  [
    :anchor, :protocol, :query_tokens,
    :path, :host, :port, :username, :password
  ]
  COMBINED_PARTS = [
    :hostinfo, :userinfo, :authority, :ssl, :domain, :domainname, 
    :domainzone, :request, :location, :query,
    :extension, :filename
  ]
  PARTS = ESSENTIAL_PARTS + COMBINED_PARTS

  ALIASES = {
    protocol: [:schema, :scheme],
    anchor: [:fragment],
    host: [:hostname],
    username: [:user],
    request: [:request_uri]
  }

  DELEGATES = [:port!, :host!, :path!, :home_page?]

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

  class FormattingError < StandardError
  end

end
