# frozen-string-literal: true

# Based on FormModel this allows one to define a translation between data in one form and another, ie what FormModel
# allows us to do, but with some tweaks to support the idea of the named schema types.
#
# It introduces a new 'typed attribute' called `api_schema` for which attributes can be defined with the  `nested`
# DSL method.
#
#   nested :registered_user, ::Api::Schemas::User, allow_nil: false
#
# Note all features of `::TypedSupport::FormModel` can also be used in the `::TypedSupport::ApiModelSchema`
module TypedSupport
  class ApiModelSchema
    include ::TypedSupport::FormModel

    class << self
      def name
        @klass_name
      end

      attr_reader :schema_name

      def nested(name, schema, **options)
        options[:validates] = true
        options[:allow_blank] = false if options[:allow_blank].nil? && options[:allow_nil].nil?
        attr_method(name, options, :api_schema, schema, true) do |value|
          schema.new(value).schema(options.fetch(:schema, self.class.schema_name), @_schema_context)
        end
      end

      def nested_collection(name, schema, **options)
        options[:validates] = true
        options[:allow_blank] = false if options[:allow_blank].nil? && options[:allow_nil].nil?
        options[:convert] = true
        attr_method(name, options, Array, schema, true) do |values|
          values.map do |value|
            schema.new(value).schema(options.fetch(:schema, self.class.schema_name), @_schema_context)
          end
        end
      end

      def attribute_options(attr_name, prev_options, type_klass, sub_type, convertable = false, &converter)
        options = prev_options.dup
        unless options[:mapping] && options[:mapping][:model]
          options[:mapping] = {} unless options[:mapping]
          options[:mapping][:model] = :model
        end
        super(attr_name, options, type_klass, sub_type, convertable, &converter)
      end

      # Override to support mappings to associations of model being serialised
      def from_models(models, options = {})
        form = new({}, options.fetch(:persisted, true))
        form.instance_variable_set(:@_schema_context, options[:context])
        data = super(models, options, form)
        attribute_options_for_named_mapping.each do |_key, mapping|
          next if mapping[:model] == :model
          nested_attrs = super({mapping[:model] => models[:model].send(mapping[:model])}, options)
          nested_attrs.instance_variables.each do |ivar|
            data.instance_variable_set(ivar, nested_attrs.instance_variable_get(ivar))
          end
        end
        data
      end
    end

    # Allow the constructor to be called with attributes which are not defined on the schema, they are simply ignored.
    def initialize(model = {}, persisted = false, convert_all = false)
      assigned_attrs = {}
      attribute_names.each do |n|
        if model.respond_to?(n)
          assigned_attrs[n] = model.send(n)
        elsif model.respond_to?(:[]) && !model[n].nil?
          assigned_attrs[n] = model[n]
        end
      end
      super(assigned_attrs, persisted, convert_all)
    end

    def inspect
      "#<#{self.class.name}<::TypedSupport::ApiModelSchema> #{to_json}>"
    end

    private

    def type_valid?(val, type, type_klass, sub_type, allow_nil)
      return true if allow_nil && val.nil?
      case type
      when :api_schema
        is_schema = val.is_a?(::TypedSupport::ApiModelSchema)
        is_schema && sub_type.ancestors.include?(::TypedSupport::ApiSchema)
      else
        super
      end
    end
  end
end
