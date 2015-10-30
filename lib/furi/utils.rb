
module Furi
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
end
 
