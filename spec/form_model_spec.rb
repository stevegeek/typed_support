# frozen_string_literal: true

require "spec_helper"
require "typed_support/form_model"

RSpec.describe TypedSupport::FormModel do
  let(:fake_user_model_class) do
    Class.new do
      include ActiveModel::Model
      attr_accessor :first_name, :surname

      def attributes
        {"first_name" => first_name, "surname" => surname}
      end
    end
  end

  let(:fake_user_profile_class) do
    Class.new do
      include ActiveModel::Model
      attr_accessor :age, :my_packed_hobbies

      attr_accessor :form

      def attributes
        {"age" => 25, "my_packed_hobbies" => %w[code food]}
      end

      def virtual_thing
        123
      end
    end
  end

  let(:fake_other_form) do
    Class.new do
      include TypedSupport::FormModel

      attr_string :message
    end
  end

  let(:test_form_model) do
    Class.new do
      include TypedSupport::FormModel

      attr_boolean :selected, default: false
      attr_integer :id, convert: false
      attr_array :settings
      attr_array :choices

      attr_string :first_name, mapping: {model: :user}
      attr_string :last_name, mapping: {model: :user, attribute: :surname}
      attr_integer :age, mapping: {model: :user_profile}
      attr_integer :virtual_thing, mapping: {model: :user_profile}
      attr_array :hobbies, mapping: {model: :user_profile, attribute: :my_packed_hobbies, compact: true}

      attr_model :another_form,
        type: TestAnotherFormModel,
        mapping: {model: :user_profile, attribute: :form},
        convert: true
    end
  end

  let(:convertable_form) do
    TestFormModel.new(
      {
        first_name: "Bob",
        id: 123,
        another_form: {message: "Hello"}
      },
      false
    )
  end

  let(:equivalent_form) do
    TestFormModel.new(
      {
        first_name: "Bob",
        id: 123,
        another_form: TestAnotherFormModel.new(message: "Hello")
      },
      true
    )
  end

  let(:persisted_form) do
    TestFormModel.new(
      {
        first_name: "Bob",
        last_name: "Tester"
      },
      true
    )
  end

  let(:merged_form) do
    TestFormModel.new(
      {
        first_name: "Steve",
        last_name: "Test",
        age: 25,
        virtual_thing: 123,
        hobbies: %w[code food],
        another_form: TestAnotherFormModel.new(message: "Hello")
      },
      true
    )
  end

  before do
    stub_const("TestAnotherFormModel", fake_other_form)
    stub_const("FakeModelUser", fake_user_model_class)
    stub_const("FakeUserProfile", fake_user_profile_class)
    stub_const("TestFormModel", test_form_model)
  end

  describe ".from_params" do
    it "converts from a params hash" do
      expect(
        TestFormModel.from_params({
          "first_name" => "Bob",
          "id" => "123",
          "another_form_attributes" => {message: "Hello"}
        })
      ).to eq convertable_form
    end
  end

  describe ".from_model" do
    it "builds from an AR model" do
      allow_any_instance_of(TestFormModel).to receive(:persisted?).and_return(true)
      expect(
        TestFormModel.from_model(
          FakeModelUser.new(first_name: "Bob", surname: "Tester"),
          allowed_attributes: {first_name: :first_name, last_name: :surname}
        )
      ).to eql persisted_form
    end
  end

  describe ".from_models" do
    let(:user_profile) do
      FakeUserProfile.new(age: 25, my_packed_hobbies: %w[code food], form: TestAnotherFormModel.new(message: "Hello"))
    end

    it "builds from a set of model object" do
      expect(
        TestFormModel.from_models(
          {
            user: FakeModelUser.new(first_name: "Steve", surname: "Test"),
            user_profile: user_profile
          }, {persisted: true}
        )
      ).to eql merged_form
    end
  end

  describe ".to_model_attributes" do
    it "returns the right attributes for each named model" do
      expect(merged_form.to_model_attributes(:user)).to eql("first_name" => "Steve", "surname" => "Test")
      expect(merged_form.to_model_attributes(:user_profile)).to eql(
        "age" => 25,
        "virtual_thing" => 123,
        "my_packed_hobbies" => %w[code food],
        "form" => TestAnotherFormModel.new(message: "Hello")
      )
    end
  end

  describe ".form_name" do
    it "is the param_key name" do
      expect(TestFormModel.form_name).to eq "test_form_model"
    end
  end

  describe ".attribute_names" do
    it "returns the attr names" do
      expect(TestFormModel.attribute_names).to eq %w[
        selected id settings choices first_name last_name age virtual_thing hobbies another_form
      ]
    end
  end

  describe ".keys_for_permit" do
    let(:param_config) do
      [
        "selected",
        "id",
        {"settings" => []},
        {"choices" => []},
        "first_name",
        "last_name",
        "age",
        "virtual_thing",
        {"hobbies" => []},
        {"another_form_attributes" => ["message"]}
      ]
    end

    it "returns the params permit structure" do
      expect(TestFormModel.keys_for_permit).to eq param_config
    end
  end

  describe "#==" do
    it "checks equality of attrs" do
      expect(convertable_form == equivalent_form).to be true
    end
  end

  describe "#[]" do
    it "allows one to access attrs" do
      expect(persisted_form[:first_name]).to be "Bob"
      expect { persisted_form[:third] }.to raise_error StandardError
    end
  end

  describe "#persisted?" do
    it "respects persisted" do
      expect(persisted_form.persisted?).to be true
    end
  end

  describe "#attributes" do
    it "returns a indifferent hash" do
      expect(persisted_form.attributes[:first_name]).to be "Bob"
      expect(persisted_form.attributes["first_name"]).to be "Bob"
    end

    it "returns a hash of attributes" do
      expect(persisted_form.attributes[:first_name]).to be "Bob"
      expect(persisted_form.attributes[:selected]).to be false
      expect(persisted_form.attributes.key?(:settings)).to be false
    end
  end
end
