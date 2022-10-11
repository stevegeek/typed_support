# frozen_string_literal: true

require "active_support/concern"
require "active_support/hash_with_indifferent_access"
require "active_support/core_ext/hash"
require "active_support/core_ext/object/instance_variables"
require "active_support/core_ext/object/json"
require "active_model"
require "active_model/validations"
require "active_model/validations/callbacks"
require "active_record"

module TypedSupport
  module TypedAttributesModel
    extend ActiveSupport::Concern

    include ActiveModel::Model
    include ActiveModel::Validations::Callbacks

    class NotNilValidator < ActiveModel::EachValidator
      def validate_each(record, attribute, value)
        record.errors.add(attribute, "must not be nil") if value.nil?
      end
    end

    # TODO: review this, can we generalise some to 'typed' ones?
    SUPPORTED_PRIMITIVES = [String, Float, Integer, Numeric, Symbol, Hash, Array].freeze

    class_methods do
      def inherited(subclass)
        subclass.instance_variable_set(:@attribute_store, @attribute_store.clone)
        super
      end

      # Note: this methods is similar to https://dry-rb.org/gems/dry-types/1.2/.
      # We should evaluate whether it makes sense to move to https://dry-rb.org/gems/dry-initializer/3.0/
      #
      # Defines an attribute which we want to represent an instance of some class
      # It is also possible to specify a 'type' option, which is the Class of the model
      def attribute(name, type = :any, **options)
        sub_type = options[:type] || options[:sub_type]
        attr_method(name, options, type, sub_type) do |v|
          block_given? ? yield(v) : convert_primitives(type, sub_type, v)
        end
      end

      # Add a form attribute of any type, prefer over attr_accessor for adding behaviour
      # around attribute mapping
      def attr_any(name, **options)
        attribute(name, :any, **options) { |v| v }
      end

      # Define an attribute which we want to be a hash when assigned
      # Conversion is defined as a to_h
      def attr_hash(name, **options)
        attribute(name, Hash, **options, &:to_h)
      end

      # Define an attribute which we want to be a boolean value when assigned.
      # Conversion is defined as a present?
      def attr_boolean(name, **options)
        attribute(name, :boolean, **options) do |v|
          next false if v == "false"
          v.present?
        end
      end

      # Define an attribute which we want to be a string value when assigned.
      # Conversion is defined as :to_s
      def attr_string(name, **options)
        attribute(name, String, **options, &:to_s)
      end

      # Define an attribute which we want to be a float value when assigned.
      # Conversion is defined as :to_f
      def attr_float(name, **options)
        attribute(name, Float, **options, &:to_f)
      end

      # Define an attribute which we want to be a numeric value when assigned.
      # Conversion is defined as :to_f
      def attr_numeric(name, **options)
        attribute(name, Numeric, **options) do |v|
          v.present? ? v.to_f : options&.fetch(:default, nil)
        end
      end

      # Define an attribute which we want to be an integer value when assigned.
      # Conversion is defined as :to_i
      def attr_integer(name, **options)
        attribute(name, Integer, **options, &:to_i)
      end

      # Define an attribute which we want to be a symbol value when assigned.
      # Conversion is defined as :to_sym
      def attr_symbol(name, **options)
        attribute(name, Symbol, **options, &:to_sym)
      end

      # Define an attribute which we want to be an array value when assigned.
      # It is also possible to specify a 'type' option, which is the Class of the instances inside the array
      # FIXME: It is not possible to use primitive types like Integer
      # Conversion is defined as :to_a
      def attr_array(name, **options)
        attribute(name, Array, **options) do |v|
          converted = v.to_a
          klass = options[:type] || options[:sub_type]
          converted =
            converted.map do |member|
              next member if !klass || member.is_a?(klass)

              # FIXME: form models shouldnt have their own handling here, we need to think about how to better account
              # for an array of Form models which are built from params from `x_attributes` assignments
              next klass.from_params(member) if klass.respond_to?(:from_params)
              klass.new(member)
            end
          converted
        end
      end

      # Define an attribute which we want to represent an active model instance value when assigned.
      # It is also possible to specify a 'type' option, which is the Class of the model
      def attr_model(name, **options)
        attribute(name, :model, **options) { |v| options[:type].new(v, false, true) }
      end

      # Attribute(s) introspection methods

      def attribute_names
        @attribute_store&.keys || []
      end

      def attribute_keys
        (@attribute_store&.keys || []).map(&:to_sym)
      end

      def allows_nil?(name)
        options = attribute_configuration(name)
        return true unless options
        allow_blank = options[:allow_blank]
        allow_nil = options.fetch(:allow_nil, true)
        allow_blank == false ? false : allow_nil
      end

      def allows_blank?(name)
        options = attribute_configuration(name)
        return true unless options
        allow_blank = options[:allow_blank]
        allow_blank.nil? ? true : allow_blank
      end

      def attribute_configuration(name)
        @attribute_store&.fetch(name, nil)
      end

      private

      def attribute_allows_nil?(options)
        allow_blank = options[:allow_blank]
        allow_nil = options.fetch(:allow_nil, true)
        allow_blank == false ? false : allow_nil
      end

      def attribute_allows_blank?(options)
        allow_blank = options[:allow_blank]
        allow_blank.nil? ? true : allow_blank
      end

      def attr_method(attr_name, options, type, sub_type, convertable = false, &converter)
        attr_options =
          attribute_options(attr_name, options, type, sub_type, convertable, &converter)
        @attribute_store ||= HashWithIndifferentAccess.new
        @attribute_store[attr_name] = attr_options

        # The reader method will return the specified attribute default if appropriate
        ivar_name = "@#{attr_name}"
        define_attribute_reader(attr_name, attr_options, ivar_name)
        define_attribute_writer(attr_name, attr_options, ivar_name)
        define_attribute_validators(attr_name, attr_options)
      end

      def attribute_options(
        attr_name,
        options,
        type_klass,
        sub_type,
        convertable = false,
        &converter
      )
        type = type_klass.is_a?(Symbol) ? type_klass : convert_to_internal_type(type_klass)
        attr_opts = {
          attr_name: attr_name,
          setter_name: :"#{attr_name}=",
          allow_nil: attribute_allows_nil?(options), # Allow attribute value to be set to nil
          allow_blank: attribute_allows_blank?(options), # Allow attribute value to be set to a `blank` value
          blank_to_nil: options[:blank_to_nil], # Attribute blanks are converted to nil
          in: options[:in], # Limit to only values in list
          validates: options[:validates], # Validate sub attribute
          type_klass: type_klass, # Attribute type
          type: type, # Attribute type as understood internally by TypedAttrs
          sub_type: sub_type, # Collection elements type
          convert: options.fetch(:convert, convertable), # Should convert value to attribute type on set
          strip: options[:strip], # Should strip value
          converter: converter # The proc used to convert value
        }
        attr_opts[:default] = options[:default] if options.key?(:default)
        attr_opts.freeze
      end

      def define_attribute_reader(attr_name, attr_options, ivar_name)
        # Define reader
        define_method(attr_name) do
          value = instance_variable_get(ivar_name)
          default = attr_options[:default]
          if !value.nil?
            value
          elsif default.is_a?(Proc)
            default.call(self)
          else
            default
          end
        end

        # Define presence check method
        define_method(:"#{attr_name}?") { send(attr_name).present? }
      end

      def define_attribute_writer(attr_name, attr_options, ivar_name)
        # The writer performs the type check and when a nested model instantiates
        define_method(attr_options[:setter_name]) do |v, force_convert = false|
          opts = attr_options # self.class.attribute_configuration(attr_name)

          v = nil if opts[:blank_to_nil] == true && v.respond_to?(:blank?) && v.blank?

          break instance_variable_set(ivar_name, v) if opts[:type] == :any

          check_presence!(v, opts[:attr_name], opts[:allow_nil], opts[:allow_blank])

          valid = type_valid?(v, opts[:type], opts[:type_klass], opts[:sub_type], opts[:allow_nil])
          break set_ivar_value(attr_name, ivar_name, v, opts[:in], opts[:strip]) if valid

          # Attempt to convert if we should
          convert = (force_convert || opts[:convert]) && !v.nil?
          converted = instance_exec(v, &opts[:converter]) if convert
          if convert
            valid =
              type_valid?(
                converted,
                opts[:type],
                opts[:type_klass],
                opts[:sub_type],
                opts[:allow_nil]
              )
          end
          raise_type_error!(attr_name, opts, v) unless convert && valid
          set_ivar_value(attr_name, ivar_name, converted, opts[:in], opts[:strip])
        end
      end

      def define_attribute_validators(attr_name, attr_options)
        # Add validations, for excluding nil value or blanks
        validates(attr_name, not_nil: true) unless allows_nil?(attr_name)
        validates_presence_of(attr_name) unless allows_blank?(attr_name)

        return unless attr_options[:validates]
        validates_each(attr_name) do |record, attr, value|
          next if value.blank?
          is_valid = attr_options[:type] == :array ? value.each(&:valid?) : value.valid?
          record.errors.add attr, "#{attr} is not valid" unless is_valid
        end
      end

      def convert_to_internal_type(type_klass)
        return type_klass.name.downcase.to_sym if SUPPORTED_PRIMITIVES.include?(type_klass)
        :typed
      end
    end

    # Assign attrs - ignore unknown allows you to ignore attributes in `attrs` which there are no definitions for
    def assign(attrs, convert_all: false, ignore_unknown: false)
      attrs.each do |k, v|
        m = ivar_setter_method_name(k)
        has_method = m && respond_to?(m)
        next if ignore_unknown && !has_method
        raise NotImplementedError, "Attribute #{k} has no setter method" unless has_method
        send(m, v, convert_all)
      end
      self
    end

    # enable accessing params in a hash like way too
    def [](key)
      send(key)
    end

    def fetch(key, fallback)
      send(key) || fallback
    end

    def attribute_names
      self.class.attribute_names
    end

    def attributes
      HashWithIndifferentAccess.new(prepare_attributes)
    end
    alias_method :to_h, :attributes

    # As json returns a hash created by JSON serialiser
    def as_json(**options)
      instance_values.as_json(**options)
    end

    def inspect
      "#<#{self.class.name}<::TypedSupport::TypedAttributesModel> ...>"
    end

    protected

    def convert_primitives(type, sub_type, value)
      if type == :any
        value
      elsif type == Integer
        value.to_i
      elsif type == Float
        value.to_f
      elsif type == Symbol
        value.to_sym
      elsif type == String
        value.to_s
      elsif type == Time
        if value.is_a?(String)
          Time.zone.parse(value)
        elsif value.respond_to?(:to_time)
          value.to_time
        else
          raise ArgumentError, "Invalid time value #{value}"
        end
      elsif type == Date
        if value.is_a?(String)
          Time.zone.parse(value)&.to_date
        elsif value.respond_to?(:to_date)
          value.to_date
        else
          raise ArgumentError, "Invalid date value #{value}"
        end
      elsif type == Array
        sub_type&.respond_to?(:new) ? value.map { |v| sub_type.new(v) } : value
      else
        type.respond_to?(:new) ? type.new(value) : value
      end
    end

    def type_valid?(val, type, type_klass, sub_type, allow_nil)
      return true if allow_nil && val.nil?
      case type
      when :boolean
        val.is_a?(TrueClass) || val.is_a?(FalseClass)
      when :string
        val.is_a?(String)
      when :float
        val.is_a?(Float)
      when :integer
        val.is_a?(Integer)
      when :numeric
        val.is_a?(Numeric)
      when :symbol
        val.is_a?(Symbol)
      when :hash
        val.is_a?(Hash) || val.is_a?(OpenStruct)
      when :typed
        val.is_a?(type_klass)
      when :array
        is_array = val.is_a?(Array)
        if sub_type
          return is_array && val.all? do |sub_val|
            if sub_val.is_a?(::TypedSupport::ApiModelSchema)
              # Doing this in one line makes rubocop incorrectly change it to .instance_of? call... here we have overridden
              # the `name` method on the anonymous class
              klass = sub_val.class.name
              klass == sub_type.name
            else
              sub_val.is_a?(sub_type)
            end
          end
        end
        is_array
      when :collection
        val.is_a?(ActiveRecord::Associations::CollectionProxy)
      when :model
        is_model = val.class.include?(ActiveModel::Model) || val.is_a?(ActiveRecord::Base)
        return is_model && val.is_a?(sub_type) if sub_type
        is_model
      else
        raise NotImplementedError, "No handling of #{type}[#{sub_type}] for #{val}"
      end
    end

    # rubocop:enable Metrics/PerceivedComplexity, Metrics/MethodLength

    def ivar_setter_method_name(name)
      config = self.class.attribute_configuration(name)
      (config && config[:setter_name]) || :"#{name}="
    end

    def set_ivar_value(attr_name, ivar_name, value, in_values, strip)
      allowed = in_values.present? ? in_values.include?(value) : true
      raise_allowed_error!(attr_name, value) if allowed == false
      value = value.strip if strip && value.present?
      instance_variable_set(ivar_name, value)
    end

    def check_presence!(value, attr_name, allow_nil, allow_blank)
      klass = self.class.name
      if !allow_nil && value.nil?
        raise ArgumentError, "nil is not a valid value for '#{attr_name}' (#{klass})"
      end
      if !allow_blank && value.blank?
        raise ArgumentError, "Value cannot be 'blank?' for '#{attr_name}' (#{klass})"
      end
    end

    def raise_allowed_error!(attr_name, value)
      klass = self.class.name
      raise ArgumentError, "The value '#{value}' is not allowed for '#{attr_name}' (#{klass})"
    end

    def raise_type_error!(attr_name, opts, value)
      klass = self.class.name
      type_sig = "'#{opts[:type]}' <klass: #{opts[:type_klass]}> (subtype: #{opts[:sub_type]})"
      v_klass = "<#{value.class.name}>"
      raise TypeError,
        "The value '#{value}' is not a #{type_sig} type for '#{attr_name}' (#{klass}). It is #{v_klass}"
    end

    def prepare_attributes
      vals =
        attribute_names.map do |name|
          has_default = !!self.class.attribute_configuration(name)&.key?(:default)

          # check if set at all
          [name, send(name.to_sym)] if instance_variable_defined?("@#{name}") || has_default
        end
      vals.compact.to_h
    end
  end
end
