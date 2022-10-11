# frozen_string_literal: true

require "spec_helper"
require "typed_support/typed_attributes_model"
require "ostruct"

RSpec.describe TypedSupport::TypedAttributesModel do
  describe "assigns and stores attributes" do
    subject(:typed_instance) { MyTypedThing.new }

    let(:fake_class) do
      Class.new do
        include TypedSupport::TypedAttributesModel

        attr_symbol :first
        attr_string :second
      end
    end

    before do
      stub_const "MyTypedThing", fake_class
    end

    it "accepts values" do
      typed_instance.first = :first
      expect(typed_instance.first).to be :first
    end

    it "accepts values via #assign" do
      typed_instance.assign({first: :first, second: "string"})
      expect(typed_instance.first).to be :first
      expect(typed_instance[:first]).to be :first
      expect(typed_instance.second).to eq "string"
    end

    it "accepts values via #assign with forced convert" do
      typed_instance.assign({first: "first", second: 123}, convert_all: true)
      expect(typed_instance.first).to be :first
      expect(typed_instance[:first]).to be :first
      expect(typed_instance.second).to eq "123"
    end

    it "throws if type is wrong with #assign" do
      expect { typed_instance.assign({first: :first, second: 123}) }.to raise_error(StandardError)
    end
  end

  describe "attribute options" do
    subject(:typed_instance) { MyTypedThing.new }

    let(:fake_class) do
      Class.new do
        include TypedSupport::TypedAttributesModel

        attr_symbol :first, allow_nil: false
        attr_string :second, allow_blank: false
      end
    end

    before do
      stub_const "MyTypedThing", fake_class
    end

    it "does not accept nil if not allowed" do
      expect { typed_instance.first = nil }.to raise_error ArgumentError
    end

    it "does not accept blank if not allowed" do
      expect { typed_instance.second = "" }.to raise_error ArgumentError
    end
  end

  describe "boolean attributes" do
    subject(:typed_instance) { MyBooleanThing.new }

    let(:fake_class) do
      Class.new do
        include TypedSupport::TypedAttributesModel

        attr_boolean :first
        attr_boolean :second, default: true
        attr_boolean :third, allow_nil: true
        attr_boolean :fourth, convert: true
        attr_boolean :fifth, allow_nil: false
      end
    end

    before do
      stub_const "MyBooleanThing", fake_class
    end

    it "has correct attributes" do
      typed_instance.first = true
      typed_instance.second = false
      typed_instance.third = false
      expect(typed_instance.first).to be true
      expect(typed_instance.second).to be false
      expect(typed_instance.third).to be false
    end

    it "returns nil if allowed" do
      typed_instance.first = nil
      typed_instance.third = nil
      expect(typed_instance.third).to be nil
    end

    it "returns default" do
      typed_instance.first = true
      expect(typed_instance.second).to be true
    end

    it "exposes a presence method" do
      expect(typed_instance.first?).to be false
      expect(typed_instance.second?).to be true
    end

    it "throws if type is wrong" do
      expect { typed_instance.first = "hi" }.to raise_error(StandardError)
    end

    it "throws if nil and not allowed" do
      expect { typed_instance.fifth = nil }.to raise_error(StandardError)
    end

    it "converts type if configured to do so" do
      expect { typed_instance.fourth = "hi" }.not_to raise_error
      expect(typed_instance.fourth).to be true
    end

    it "converts type if configured to do so and value is ''" do
      expect { typed_instance.fourth = "" }.not_to raise_error
      expect(typed_instance.fourth).to be false
    end

    it "converts type if configured to do so and value is 'true'" do
      expect { typed_instance.fourth = "true" }.not_to raise_error
      expect(typed_instance.fourth).to be true
    end

    it "converts type if configured to do so and value is 'false'" do
      expect { typed_instance.fourth = "false" }.not_to raise_error
      expect(typed_instance.fourth).to be false
    end
  end

  describe "string attributes" do
    subject(:typed_instance) { MyStringThing.new }

    let(:fake_class) do
      Class.new do
        include TypedSupport::TypedAttributesModel

        attr_string :first, allow_nil: false
        attr_string :second, default: "hi"
        attr_string :third, allow_nil: true
        attr_string :fourth, convert: true
        attr_string :fifth, allow_nil: true, allow_blank: false
      end
    end

    before do
      stub_const "MyStringThing", fake_class
    end

    it "renders with nil if allowed" do
      typed_instance.first = "a"
      typed_instance.third = nil
      expect(typed_instance.third).to be nil
    end

    it "renders with default" do
      typed_instance.first = "b"
      expect(typed_instance.second).to be "hi"
    end

    it "exposes a presence method" do
      expect(typed_instance.third?).to be false
      expect(typed_instance.second?).to be true
    end

    it "throws if type is wrong" do
      expect { typed_instance.first = true }.to raise_error(StandardError)
    end

    it "throws if nil and not allowed" do
      expect { typed_instance.first = nil }.to raise_error(StandardError)
    end

    it "throws if blank and not allowed" do
      expect { typed_instance.fifth = nil }.to raise_error(StandardError)
    end

    it "converts type if configured to do so" do
      expect { typed_instance.fourth = 123 }.not_to raise_error
      expect(typed_instance.fourth).to eq "123"
    end
  end

  describe "model attributes and sub validations" do
    subject(:typed_instance) { MyModelThing.new }

    let(:fake_class) do
      Class.new do
        include TypedSupport::TypedAttributesModel

        attr_model :first
        attr_model :second, type: AnotherModelClass, validates: true
      end
    end

    let(:model_class) do
      Class.new do
        include TypedSupport::FormModel
      end
    end

    let(:another_model_class) do
      Class.new do
        include TypedSupport::FormModel

        attr_string :name, allow_blank: false
      end
    end

    before do
      stub_const "ModelClass", model_class
      stub_const "AnotherModelClass", another_model_class
      stub_const "MyModelThing", fake_class
    end

    it "accepts models" do
      typed_instance.first = ModelClass.new
      expect(typed_instance.first).to be_instance_of ModelClass
    end

    it "accepts sub typed models" do
      typed_instance.second = AnotherModelClass.new
      expect(typed_instance.second).to be_instance_of AnotherModelClass
    end

    it "is invalid as associated model invalid" do
      typed_instance.second = AnotherModelClass.new
      expect(typed_instance.valid?).to be false
    end

    it "is valid as associated model valid" do
      typed_instance.second = AnotherModelClass.new(name: "test")
      expect(typed_instance.valid?).to be true
    end

    it "throws if type is wrong" do
      expect { typed_instance.first = true }.to raise_error(StandardError)
    end

    it "throws if sub type is wrong" do
      expect { typed_instance.second = ModelClass.new }.to raise_error(StandardError)
    end
  end

  describe "typed attributes" do
    subject(:typed_instance) { MyModelThing.new }

    let(:fake_class) do
      Class.new do
        include TypedSupport::TypedAttributesModel

        attribute :first, String
        attribute :second, Integer, convert: true
      end
    end

    before do
      stub_const "MyModelThing", fake_class
    end

    it "accepts correct types" do
      typed_instance.first = "string"
      expect(typed_instance.first).to be "string"
    end

    it "accepts things that can convert to integer" do
      typed_instance.second = "123"
      expect(typed_instance.second).to be 123
    end

    it "throws if type is wrong" do
      expect { typed_instance.first = true }.to raise_error(StandardError)
    end
  end

  describe "symbol attributes" do
    subject(:typed_instance) { MyModelThing.new }

    let(:fake_class) do
      Class.new do
        include TypedSupport::TypedAttributesModel

        attr_symbol :first
        attr_symbol :second, convert: true
        attr_symbol :third, in: [:a, :b, :c]
      end
    end

    before do
      stub_const "MyModelThing", fake_class
    end

    it "accepts symbols" do
      typed_instance.first = :first
      expect(typed_instance.first).to be :first
    end

    it "accepts things that can convert to symbol" do
      typed_instance.second = "second"
      expect(typed_instance.second).to be :second
    end

    it "accepts symbol in allowed values" do
      typed_instance.third = :a
      expect(typed_instance.third).to be :a
    end

    it "throws if value is not allowed" do
      expect { typed_instance.third = :test }.to raise_error(StandardError)
    end

    it "throws if type is wrong" do
      expect { typed_instance.first = true }.to raise_error(StandardError)
    end
  end

  describe "array attributes" do
    subject(:typed_instance) { MyModelThing.new }

    let(:fake_class) do
      Class.new do
        include TypedSupport::TypedAttributesModel

        attr_array :first
        attr_array :second, type: AnotherModelClass
        attr_array :third, type: AnotherModelClass, convert: true
      end
    end

    let(:another_model_class) do
      Class.new do
        include TypedSupport::FormModel
      end
    end

    before do
      stub_const "AnotherModelClass", another_model_class
      stub_const "MyModelThing", fake_class
    end

    it "accepts arrays" do
      typed_instance.first = [1, 2, 3]
      expect(typed_instance.first).to eql [1, 2, 3]
    end

    it "accepts sub typed arrays" do
      typed_instance.second = [AnotherModelClass.new, AnotherModelClass.new]
      expect(typed_instance.second.size).to be 2
      expect(typed_instance.second.first).to be_instance_of AnotherModelClass
    end

    it "accepts sub typed values to convert" do
      typed_instance.third = [{}]
      expect(typed_instance.third.first).to be_a_kind_of AnotherModelClass
    end

    it "accepts sub typed values to convert that are already correct type" do
      typed_instance.third = [AnotherModelClass.new]
      expect(typed_instance.third.first).to be_a_kind_of AnotherModelClass
    end

    it "throws if type is wrong" do
      expect { typed_instance.first = true }.to raise_error(StandardError)
    end

    it "throws if sub type is wrong" do
      expect { typed_instance.second = [1] }.to raise_error(StandardError)
    end
  end

  describe "numerical attributes" do
    subject(:typed_instance) { MyNumberThing.new }

    let(:fake_class) do
      Class.new do
        include TypedSupport::TypedAttributesModel

        attr_integer :first, allow_nil: false
        attr_float :second, default: ->(_) { 0.4 }
        attr_integer :third, allow_nil: true
        attr_float :fourth, convert: true
        attr_numeric :fifth
        attr_numeric :sixth, convert: true
      end
    end

    before do
      stub_const "MyNumberThing", fake_class
    end

    it "renders with nil if allowed" do
      typed_instance.first = 123
      typed_instance.third = nil
      expect(typed_instance.third).to be nil
    end

    it "renders with default" do
      typed_instance.first = 131
      expect(typed_instance.second).to be 0.4
    end

    it "lets numeric values in numeric types" do
      expect { typed_instance.fifth = 123 }.not_to raise_error
      expect { typed_instance.fifth = 1.0 }.not_to raise_error
    end

    it "exposes a presence method" do
      typed_instance.first = 0
      expect(typed_instance.first?).to be true
      expect(typed_instance.third?).to be false
    end

    it "throws if type is wrong" do
      expect { typed_instance.first = true }.to raise_error(StandardError)
      expect { typed_instance.fifth = true }.to raise_error(StandardError)
    end

    it "throws if nil and not allowed" do
      expect { typed_instance.first = nil }.to raise_error(StandardError)
    end

    it "converts type if configured to do so" do
      expect { typed_instance.fourth = "123" }.not_to raise_error
      expect(typed_instance.fourth).to eq 123.0
    end

    it "converts type if configured to do so and numeric" do
      expect { typed_instance.sixth = "123" }.not_to raise_error
      expect(typed_instance.sixth).to eq 123.0
    end
  end

  describe "hash and any attributes" do
    subject(:typed_instance) { TypedAttributesModelAttrHashAndAnyClass.new }

    let(:fake_class) do
      Class.new do
        include TypedSupport::TypedAttributesModel

        attr_hash :first, allow_nil: false
        attr_hash :second, default: {}
        attr_any :third
        attr_hash :fourth, convert: true
      end
    end

    before do
      stub_const "TypedAttributesModelAttrHashAndAnyClass", fake_class
    end

    it "allows nil if allowed" do
      typed_instance.first = {}
      typed_instance.third = nil
      expect(typed_instance.third).to be nil
    end

    it "returns default" do
      typed_instance.first = {a: 1}
      expect(typed_instance.second).to eql({})
    end

    it "exposes a presence method" do
      typed_instance.first = {a: 1}
      expect(typed_instance.first?).to be true
      expect(typed_instance.third?).to be false
      expect(typed_instance.fourth?).to be false
    end

    it "throws if type is wrong" do
      expect { typed_instance.first = true }.to raise_error(StandardError)
    end

    it "throws if nil and not allowed" do
      expect { typed_instance.first = nil }.to raise_error(StandardError)
    end

    it "converts type if configured to do so" do
      expect { typed_instance.fourth = [%w[a abc], ["b", 1]] }.not_to raise_error
      expect(typed_instance.fourth).to eql("a" => "abc", "b" => 1)
    end
  end

  describe ".attribute_names" do
    let(:fake_class) do
      Class.new do
        include TypedSupport::TypedAttributesModel

        attr_boolean :first
        attr_integer :second
      end
    end

    before do
      stub_const "TypedAttributesModelAttrNamesTestClass", fake_class
    end

    it "returns typed attributes" do
      expect(TypedAttributesModelAttrNamesTestClass.attribute_names).to eql %w[first second]
    end
  end

  describe "#as_json" do
    subject(:typed_instance) { MyJSONedThing.new(first: true, second: 213) }

    let(:fake_class) do
      Class.new do
        include TypedSupport::TypedAttributesModel

        attr_boolean :first
        attr_integer :second
      end
    end

    before do
      stub_const "MyJSONedThing", fake_class
    end

    it "has all key/val pairs" do
      expect(typed_instance.as_json).to eq("first" => true, "second" => 213)
    end

    it "respects non string" do
      expect(typed_instance.as_json["first"]).to eq true
    end
  end

  describe "convert all attributes" do
    subject(:typed_instance) { MyConvertableThing.new(first: "hi", second: "1.2") }

    let(:fake_class) do
      Class.new do
        include TypedSupport::TypedAttributesModel

        attr_boolean :first, convert: true
        attr_float :second, convert: true
      end
    end

    before do
      stub_const "MyConvertableThing", fake_class
    end

    it "has converted key/value pairs" do
      expect(typed_instance.as_json).to eq("first" => true, "second" => 1.2)
    end
  end

  describe "attributes of any type" do
    subject(:typed_instance) { MyAnyTypeThing.new }

    let(:fake_class) do
      Class.new do
        include TypedSupport::TypedAttributesModel

        attr_any :first
      end
    end

    before do
      stub_const "MyAnyTypeThing", fake_class
    end

    it "accepts any type" do
      obj = OpenStruct.new(a: 1)
      typed_instance.first = 123
      typed_instance.first = {stuff: "abc"}
      typed_instance.first = obj
      expect(typed_instance.first).to be obj
    end
  end

  describe "attributes with mapping configuration in options" do
    subject(:typed_instance) { MyAttributesMappedThing.new }

    let(:fake_class) do
      Class.new do
        include TypedSupport::TypedAttributesModel

        attr_boolean :first, default: false, mapping: {model: OpenStruct, name: :the_first_attribute}
        attr_array :second, mapping: {model: OpenStruct, name: :the_second_attribute, compact: true}
      end
    end

    before do
      stub_const "MyAttributesMappedThing", fake_class
    end

    it "accepts further options" do
      typed_instance.first = true
      typed_instance.second = [3, 2]
      expect(typed_instance.first).to be true
    end
  end
end
