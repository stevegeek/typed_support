# frozen_string_literal: true

require "spec_helper"
require "typed_support/hashed_key"


RSpec.describe TypedSupport::HashedKey do
  describe ".call" do
    let(:ar) do
      Class.new do
        def cache_key_with_version
          "users/cache_key"
        end
      end.new
    end

    let(:test_instance) do
      k = Class.new do
        include ::TypedSupport::TypedAttributesModel

        def cache_key
          "my_key"
        end
      end
      k.new
    end

    it "generates a key from a active record like instance" do
      expect(described_class.call(ar)).to start_with "users/cache_key"
    end

    it "generates a key from a presenter" do
      expect(described_class.call(test_instance)).to eql "my_key"
    end

    it "generates a key from an array" do
      expect(described_class.call([1, 2, 3])).to eql "59d2728452ee6cb3214f5b0deafd86214a2c6ddb"
    end

    it "generates a key from a hash" do
      expect(described_class.call(a: 1, b: 2)).to eql "58df4c0192c6a26f9921bba82704457b9e40e755"
    end

    it "generates a key from a string" do
      expect(described_class.call("dlkjw")).to eql "dda58a50939583b3c85b4a980653063ea18aa71e"
    end
  end
end
