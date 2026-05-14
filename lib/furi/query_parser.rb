module Furi
  class QueryParser
    def initialize(
      make_params: -> { {} },
      depth_limit: 100,
      encoding_template: nil,
      coerce_value: nil,
      deep_munge: false
    )
      @make_params = make_params
      @depth_limit = depth_limit
      @encoding_template = encoding_template
      @coerce_value = coerce_value
      @deep_munge = deep_munge
    end

    def parse(query)
      return Furi::Utils.stringify_keys(query) if query.is_a?(Hash)

      params = @make_params.call
      Furi.query_tokens(query).each do |token|
        parse_token(params, token.name, coerce(token.value), 0)
      end
      params
    end

    private

    def coerce(value)
      return value unless @coerce_value
      coerced = @coerce_value.call(value)
      coerced.nil? ? value : coerced
    end

    def parse_token(params, name, value, depth)
      raise Furi::ParamsTooDeepError if depth >= @depth_limit

      if depth == 0
        # At depth 0, use Rails-compatible splitting: find the first [ after
        # position 0, treating everything before it as the key. This preserves
        # leading brackets (e.g. "[foo]" stays "[foo]", not "foo").
        if (bracket = (name || "").index("[", 1))
          k = name[0, bracket]
          after = name[bracket..]
        else
          k = name || ""
          after = ""
        end
      else
        name =~ %r(\A[\[\]]*([^\[\]]+)\]*)
        k = $1 || ""
        after = $' || ""
      end

      return if k.empty?

      unless k.valid_encoding?
        raise Furi::InvalidParameterError, "Invalid encoding for parameter: #{k}"
      end

      if depth == 0 && String === value
        if @encoding_template && (enc = @encoding_template[k]) && !value.frozen?
          value.force_encoding(enc)
        end
        unless value.valid_encoding?
          raise Furi::InvalidParameterError, "Invalid encoding for parameter: #{value.scrub}"
        end
      end

      current = params[k]
      if after == ""
        current = value
      elsif after == "[]"
        current ||= []
        unless current.is_a?(Array)
          raise Furi::ParameterTypeError, "expected Array (got #{current.class}) for param `#{k}'"
        end
        current << value if value || !@deep_munge
      elsif after =~ %r(^\[\]\[([^\[\]]+)\]$) || after =~ %r(^\[\](.+)$)
        child_key = $1
        current ||= []
        unless current.is_a?(Array)
          raise Furi::ParameterTypeError, "expected Array (got #{current.class}) for param `#{k}'"
        end
        if current.last.is_a?(Hash) && !current.last.key?(child_key)
          parse_token(current.last, child_key, value, depth + 1)
        else
          current << parse_token(@make_params.call, child_key, value, depth + 1)
        end
      else
        current ||= @make_params.call
        unless current.is_a?(Hash)
          raise Furi::ParameterTypeError, "expected Hash (got #{current.class}) for param `#{k}'"
        end
        current = parse_token(current, after, value, depth + 1)
      end
      params[k] = current

      params
    end
  end
end
