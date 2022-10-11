# frozen_string_literal: true

require "typed_support/typed_attributes_model"

module TypedSupport
  module FormModel
    extend ActiveSupport::Concern

    include TypedSupport::TypedAttributesModel

    class_methods do
      # Initialize the form model from a form params hash
      def from_params(params, persisted: false, extract: false)
        params = params.fetch(form_name, {}).permit(keys_for_permit) if extract
        new(params, persisted, true)
      end

      # Initialize the form from a single ActiveRecord model
      # Optionally specify allowed attributes as either an array of attribute names, or an object specify the mappings
      # between form names and model names
      def from_model(model, allowed_attributes: nil)
        attrs = HashWithIndifferentAccess.new(model.attributes)
        selected_attrs = attrs.slice(*attribute_names) if allowed_attributes.nil?
        selected_attrs = attrs.slice(*allowed_attributes) if allowed_attributes.is_a? Array
        selected_attrs ||=
          allowed_attributes.each_with_object({}) do |keys, acc|
            key, attr_key = keys
            acc[key] = attrs[attr_key]
          end
        new(selected_attrs, model.persisted?)
      end

      def from_models(models, options = {}, form = new({}, options.fetch(:persisted, true)))
        models.each do |name, instance|
          next unless instance
          selected_mappings = attribute_options_for_named_mapping(name)
          selected_attrs =
            selected_mappings.map do |form_name, mapping|
              attr_mapping = mapping.fetch(:attribute, form_name).to_sym
              value =
                if mapping[:to].is_a?(Proc)
                  mapping[:to].call(instance, options[:context])
                elsif instance.respond_to?(attr_mapping)
                  instance.send(attr_mapping)
                else
                  instance[attr_mapping]
                end
              value = value[mapping[:index]] if mapping[:index].present?
              value = mapping[:transform].call(value) if mapping[:transform].present?

              # Only try to assign a value if it exists on the input data (ie dont assume its 'nil' if key not present)
              if mapping[:to].is_a?(Proc) || instance.respond_to?(attr_mapping) || (instance.respond_to?(:key?) && instance.key?(attr_mapping))
                [form_name, value]
              end
            end
          selected_attrs = selected_attrs.compact.to_h
          selected_attrs.except!(*Array.wrap(options[:except]).map(&:to_s)) if options[:except]
          form.assign(selected_attrs)
        end
        others = options[:others]
        form.assign(others.is_a?(Proc) ? others.call(form) : others) if others
        form
      end

      # rubocop:enable Metrics/PerceivedComplexity, Metrics/AbcSize

      # The name of the form as per the keys in the post data
      def form_name
        model_name.param_key
      end

      # Return the permitted vals structure for strong params
      def keys_for_permit
        attribute_names.map do |key|
          config = attribute_configuration(key)
          name = key.to_s
          parse_config_to_keys(config, name)
        end
      end

      def attribute_options_for_named_mapping(model_name = nil)
        attribute_names.each_with_object({}) do |key, memo|
          config = attribute_configuration(key)
          next unless config
          mapping = config[:mapping]
          memo[key.to_s] = mapping if mapping &&
            (model_name ? mapping[:model].to_s == model_name.to_s : true)
        end
      end

      private

      # Add 'mapping' options for model to form conversion
      def attribute_options(
        attr_name,
        options,
        type_klass,
        sub_type,
        convertable = false,
        &converter
      )
        attr_options = super
        attr_options.merge(mapping: options[:mapping])
      end

      # Add a attributes writer method for nested attributes support
      # https://coderwall.com/p/kvsbfa/nested-forms-with-activemodel-model-objects
      def define_attribute_writer(attr_name, attr_options, ivar_name)
        define_method(:"#{attr_name}_attributes=") do |parameters, force_convert = false|
          if attr_options[:type] == :model && attr_options[:sub_type]
            send("#{attr_name}=", parameters, force_convert)
          elsif attr_options[:type] == :array && attr_options[:sub_type]
            arr = parameters.to_h.to_a.sort_by { |i| i.first.to_i }.map(&:last)
            send("#{attr_name}=", arr, force_convert)
          else
            raise StandardError,
              "Not sure what to do with this attribute assignment, looks like it should be a model!"
          end
        end
        super
      end

      def form_model?(klass)
        klass&.included_modules&.include?(TypedSupport::FormModel)
      end

      def parse_config_to_keys(config, name)
        keys = parse_array_config_for_keys(config, name)
        return keys if keys
        if config[:type] == :model && form_model?(config[:sub_type])
          {"#{name}_attributes" => config[:sub_type].keys_for_permit}
        elsif config[:type] == :model
          "#{name}_attributes"
        else
          name
        end
      end

      def parse_array_config_for_keys(config, name)
        return unless config[:type] == :array
        if form_model?(config[:sub_type])
          {"#{name}_attributes" => config[:sub_type].keys_for_permit}
        elsif config[:sub_type] == :model
          {"#{name}_attributes" => []}
        else
          {name => []}
        end
      end
    end

    # Instance methods
    def initialize(attrs = {}, persisted = false, convert_all = false)
      @persisted = persisted
      assign(attrs, convert_all: convert_all) if attrs.present?
    end

    attr_reader :persisted

    # Override persisted? to return optional persisted param
    alias_method :persisted?, :persisted

    def to_model_attributes(model_name, except: [])
      selected_mappings = self.class.attribute_options_for_named_mapping(model_name)
      attrs = attributes
      model_attrs = {}
      excluded = [:id] + Array.wrap(except)
      selected_mappings.each do |form_name, mapping|
        next unless attrs.key?(form_name)
        val = attrs[form_name.to_sym]
        if mapping[:back].is_a?(Proc)
          mapping[:back].call(val, model_attrs)
        else
          key = mapping.fetch(:attribute, form_name)
          next if excluded.include?(key)
          model_attrs[key] = mapping[:compact] ? val.compact : val
        end
      end
      HashWithIndifferentAccess.new(model_attrs)
    end

    def ==(other)
      other.class == self.class && other.attributes == attributes
    end

    alias_method :eql?, :==

    # In a form model the attributes should not include the :id
    def attributes
      HashWithIndifferentAccess.new(prepare_attributes.except(:id))
    end

    EXCEPT_FROM_JSON_ATTRS = [:persisted, "persisted"].freeze

    def as_json(options = {})
      prepare_attributes.as_json(options.merge(except: EXCEPT_FROM_JSON_ATTRS))
    end

    def cache_key
      ::TypedSupport::HashedKey.call(attributes)
    end
  end
end
