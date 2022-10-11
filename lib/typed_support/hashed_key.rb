# frozen_string_literal: true

require "digest/sha1"

module TypedSupport
  class HashedKey
    class << self
      def call(item)
        if item.respond_to? :cache_key_with_version
          # ActiveRecord
          item.cache_key_with_version
        elsif item.respond_to? :cache_key
          item.cache_key
        elsif item.is_a?(String)
          Digest::SHA1.hexdigest(item)
        else
          # Anything else
          Digest::SHA1.hexdigest(Marshal.dump(item))
        end
      end
    end
  end
end
