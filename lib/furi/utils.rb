
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

      def deep_merge(current_hash, other_hash)
        current_hash.merge(other_hash) do |key, this_val, other_val|
         if this_val.is_a?(Hash) && other_val.is_a?(Hash)
           deep_merge(this_val, other_val)
         else
           other_val
         end
       end
      end
    end
  end
end

