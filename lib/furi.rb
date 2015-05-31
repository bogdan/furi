require "cgi"
require "furi/version"

module Furi

  PARTS =  [
    :anchor, :protocol, :query_string, 
    :path, :host, :port, :username, :password
  ]
  ALIASES = {
    protocol: [:schema],
    anchor: [:fragment],
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
    (PARTS + ALIASES.values.flatten).each do |part|
      define_method(part) do |string|
        URI.new(string).send(part)
      end
    end
  end

  def self.update(string, parts)
    parse(string).update(parts).to_s
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
    end

    def to_s
      result = []
      if protocol
        result << "#{protocol}://"
      end
      result << authority
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

      params = {}
      @query_string.split(/[&;]/).each do |pairs|
        key, value = pairs.split('=',2).select{|v| CGI::unescape(v) }
        params[key] = value
      end
      @query = params
    end

    def query_string
      return @query_string unless query_level?
      serialize_query(@query)
      @query.select do |key, value|
        unless (value.is_a?(Hash) || value.is_a?(Array)) && value.empty?
          value.to_query(namespace ? "#{namespace}[#{key}]" : key)
        end
      end.compact.sort! * '&'

    end

    def serialize_query(query, namespace = nil)
      case query
      when Hash
        query.select do |key, value|
          unless (value.is_a?(Hash) || value.is_a?(Array)) && value.empty?
            serialize_query(value, namespace ? "#{namespace}[#{key}]" : key)
          end
        end.compact.sort! * '&'
      when Array
        query.map do |item|
          prefix = CGI.escape("#{namespace}[]")
          "#{prefix}=#{CGI.escape(item)}"
        end
      end
    end

    def expressions
      Furi.expressions
    end

    protected
    def query_level?
      !!defined?(@query)
    end
  end
end
