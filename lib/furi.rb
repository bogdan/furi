require "furi/version"
require "uri"

module Furi

  autoload :QueryParser, 'furi/query_parser'
  autoload :QueryToken, 'furi/query_token'
  autoload :Uri, 'furi/uri'
  autoload :Utils, 'furi/utils'

  ESSENTIAL_PARTS =  [
    :anchor, :protocol, :query_string,
    :path, :host, :port, :username, :password,
  ]

  COMBINED_PARTS = [
    :hostinfo, :userinfo, :authority, :ssl, :domain, :domainname,
    :domainzone, :request, :location, :endpoint, :query, :query_tokens,
    :directory, :extension, :file, :filename
  ]

  PARTS = ESSENTIAL_PARTS + COMBINED_PARTS

  ALIASES = {
    protocol: [:schema, :scheme],
    anchor: [:fragment],
    host: [:hostname],
    username: [:user],
    request: [:request_uri]
  }

  DELEGATES = [:port!, :host!, :path!, :home_page?, :https?]

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
    "mailto" => {port: nil}
  }


  SSL_MAPPING = {
    'http' => 'https',
    'ftp' => 'sftp',
    'svn' => 'svn+ssh',
  }

  WEB_PROTOCOL = ['http', 'https']

  ROOT = '/'

  # Parses a URI string and returns a Furi::Uri object.
  #
  # @param argument [String] the URI string to parse
  # @param parts [Hash, nil] optional parts to merge into the parsed URI
  # @param priority [:host, :path] controls how a protocol-less string is interpreted.
  #   When the URI has no protocol, the segment before the first +/+ is ambiguous.
  #   - +:host+ (default) treats it as the host:
  #       Furi.parse("gusiev.com/articles")
  #       # host: "gusiev.com", path: "/articles"
  #   - +:path+ treats the entire string as a path:
  #       Furi.parse("gusiev.com/articles", priority: :path)
  #       # host: nil, path: "/gusiev.com/articles"
  #   URLs with an explicit protocol are unaffected by this option.
  # @return [Furi::Uri]
  def self.parse(argument, parts: nil, priority: :host)
    Uri.new(argument, priority: priority).update(parts)
  end

  # Builds an URL from given parts
  #
  #   Furi.build(path: "/dashboard", host: 'example.com', protocol: "https")
  #     # => "https://example.com/dashboard"
  def self.build(argument)
    Uri.new(argument).to_s
  end

  class << self
    (PARTS + ALIASES.values.flatten + DELEGATES - [:query_tokens]).each do |part|
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
  class << self
    alias :merge :update
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
  # replaces newly specified parameters instead of merging to existing ones
  #
  #   Furi.update("/hello.html?a=1", host: 'gusiev.com', query: {b: 2})
  #     # => "gusiev.com/hello.html?a=1&b=2"
  #
  def self.replace(string, parts)
    parse(string).replace(parts).to_s
  end



  # Parses a query into nested paramters hash using a rack convension with square brackets.
  #
  #   Furi.parse_query("a[]=1&a[]=2")       # => {a: [1,2]}
  #   Furi.parse_query("p[email]=a&a[two]=2") # => {a: {one: 1, two: 2}}
  #   Furi.parse_query("p[one]=1&a[two]=2") # => {a: {one: 1, two: 2}}
  #   Furi.serialize({p: {name: 'Bogdan Gusiev', email: 'bogdan@example.com', data: {one: 1, two: 2}}})
  #     # => "p%5Bname%5D=Bogdan&p%5Bemail%5D=bogdan%40example.com&p%5Bdata%5D%5Bone%5D=1&p%5Bdata%5D%5Btwo%5D=2"
  def self.parse_query(query)
    QueryParser.new.parse(query)
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
      raise QueryParseError, "can not parse #{query.inspect} query tokens"
    end
  end

  # Serializes query parameters into query string.
  # Optionaly accepts a basic name space.
  #
  #   Furi.serialize({a: 1, b: 2}) # => "a=1&b=2"
  #   Furi.serialize({a: [1,2]}) # => "a[]=1&a[]=2"
  #   Furi.serialize({a: {b: 1, c:2}}) # => "a[b]=1&a[c]=2"
  #   Furi.serialize({name: 'Bogdan', email: 'bogdan@example.com'}, namespace: "person")
  #     # => "person[name]=Bogdan&person[email]=bogdan%40example.com"
  #
  def self.serialize(query, namespace: nil, sorted: false, as_hash: nil)
    serialize_tokens(query, namespace: namespace, sorted: sorted, as_hash: as_hash).join("&")
  end

  def self.join(*uris)
    uris.map do |uri|
      Furi.parse(uri)
    end.reduce do |memo, uri|
      memo.send(:join, uri)
    end
  end

  class Error < StandardError
  end

  class FormattingError < Error
  end

  class ParseError < Error
  end

  class QueryParseError < Error
  end

  class ParamError < ParseError
  end

  class ParameterTypeError < ParamError
  end

  class ParamsTooDeepError < ParamError
  end

  class InvalidParameterError < ParamError
  end

  protected

  def self.serialize_tokens(query, namespace: nil, sorted: false, as_hash: nil)
    if as_hash && !query.is_a?(Hash) && !query.is_a?(Array)
      query = as_hash.call(query) || query
    end
    case query
    when Hash
      keys = query.keys
      keys.sort_by!(&:to_s) if sorted && !namespace.to_s.include?("[]")
      result = keys.map do |key|
        value = query[key]
        unless (value.is_a?(Hash) || value.is_a?(Array)) && value.empty?
          key_param = key.respond_to?(:to_param) ? key.to_param : key
          serialize_tokens(value, namespace: namespace ? "#{namespace}[#{key_param}]" : key_param, sorted: sorted, as_hash: as_hash)
        end
      end
      result.flatten!
      result.compact!
      result
    when Array
      if namespace.nil? || namespace.empty?
        raise FormattingError, "Can not serialize Array without namespace"
      end

      namespace = "#{namespace}[]"
      query.map do |item|
        if item.is_a?(Array)
          raise FormattingError, "Can not serialize #{item.inspect} as element of an Array"
        end
        serialize_tokens(item, namespace: namespace, sorted: sorted, as_hash: as_hash)
      end
    else
      if namespace
        QueryToken.new(namespace, query)
      else
        []
      end
    end
  end


end
