module Furi
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
      
      !value.nil? ? 
        "#{encoded_key}=#{::URI.encode_www_form_component(value.to_s)}" :
        encoded_key
    end

    def as_json(options = nil)
      to_a
    end

    def inspect
      [name, value].join('=')
    end
  end
end
