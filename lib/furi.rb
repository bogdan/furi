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
    "svn" => {port: 3690},
    "svn+ssh" => {port: 22, ssl: true},
    "telnet" => {port: 23},
    "nntp" => {port: 119},
    "gopher" => {port: 70},
    "wais" => {port: 210},
    "ldap" => {port: 389},
    "prospero" => {port: 1525},
    "file" => {port: nil},
    "postgres" => {port: 5432},
    "mysql" => {port: 3306},
  }


  SSL_MAPPING = {
    'http' => 'https',
    'ftp' => 'sftp',
    'svn' => 'svn+ssh',
  }

  WEB_PROTOCOL = ['http', 'https']

  ROOT = '/'

  # Parses a given string and return an URL object
  # Optionally accepts parts to update the parsed URL object
  def self.parse(argument, parts = nil)
    Uri.new(argument).update(parts)
  end

  # Builds an URL from given parts
  #
  #   Furi.build(path: "/dashboard", host: 'example.com', protocol: "https")
  #     # => "https://example.com/dashboard"
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

  # Replaces a given URL string with given parts
  #
  #   Furi.update("http://gusiev.com", protocol: 'https', subdomain: 'www')
  #     # => "https://www.gusiev.com"
  def self.update(string, parts)
    parse(string).update(parts).to_s
  end

  # Puts the default values for given URL that are not defined
  #
  #   Furi.defaults("gusiev.com/hello.html", protocol: 'http', path: '/index.html')
  #     # => "http://gusiev.com/hello.html"
  def self.defaults(string, parts)
    parse(string).defaults(parts).to_s
  end

  # Replaces a given URL string with given parts.
  # Same as update but works different for URL query parameter:
  # merges newly specified parameters instead of replacing existing ones
  #
  #   Furi.merge("/hello.html?a=1", host: 'gusiev.com', query: {b: 2})
  #     # => "gusiev.com/hello.html?a=1&b=2"
  #
  def self.merge(string, parts)
    parse(string).merge(parts).to_s
  end


  # Parses a query into nested paramters hash using a rack convension with square brackets.
  #
  #   Furi.parse_query("a[]=1&a[]=2")       # => {a: [1,2]}
  #   Furi.parse_query("p[email]=a&a[two]=2") # => {a: {one: 1, two: 2}}
  #   Furi.parse_query("p[one]=1&a[two]=2") # => {a: {one: 1, two: 2}}
  #   Furi.serialize({p: {name: 'Bogdan Gusiev', email: 'bogdan@example.com', data: {one: 1, two: 2}}})
  #     # => "p%5Bname%5D=Bogdan&p%5Bemail%5D=bogdan%40example.com&p%5Bdata%5D%5Bone%5D=1&p%5Bdata%5D%5Btwo%5D=2"
  def self.parse_query(query)
    return Furi::Utils.stringify_keys(query) if query.is_a?(Hash)

    params = {}
    query_tokens(query).each do |token|
      parse_query_token(params, token.name, token.value)
    end

    return params
  end

  # Parses query key/value pairs from query string and returns them raw
  # without organising them into hashes and without normalising them.
  #
  #   Furi.query_tokens("a=1&b=2").map {|k,v| "#{k} -> #{v}"}  # => ['a -> 1', 'b -> 2']
  #   Furi.query_tokens("a=1&a=1&a=2").map {|k,v| "#{k} -> #{v}"}  # => ['a -> 1', 'a -> 1', 'a -> 2']
  #   Furi.query_tokens("name=Bogdan&email=bogdan%40example.com") # => [name=Bogdan, email=bogdan@example.com]
  #   Furi.query_tokens("a[one]=1&a[two]=2") # => [a[one]=1, a[two]=2]
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

  # Serializes query parameters into query string.
  # Optionaly accepts a basic name space.
  #
  #   Furi.serialize({a: 1, b: 2}) # => "a=1&b=2"
  #   Furi.serialize({a: [1,2]}) # => "a[]=1&a[]=2"
  #   Furi.serialize({a: {b: 1, c:2}}) # => "a[b]=1&a[c]=2"
  #   Furi.serialize({name: 'Bogdan', email: 'bogdan@example.com'}, "person")
  #     # => "person[name]=Bogdan&person[email]=bogdan%40example.com"
  #
  def self.serialize(query, namespace = nil)
    serialize_tokens(query, namespace).join("&")
  end

  def self.join(*uris)
    uris.map do |uri|
      Furi.parse(uri)
    end.reduce(:join)
  end

  class FormattingError < StandardError
  end

  protected

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

end
