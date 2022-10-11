# frozen-string-literal: true

# Used to describe the serialisation of data. When defining an ApiSchema one can specify multiple named schemas:
# class MySchema < ::TypedSupport::ApiSchema
#   schema do
#     # The 'default' schema
#     attr_string :uid
#     attr_string :full_name
#     nested :profile ...
#     ...
#   end
#
#   schema(:minimal) do
#     # The 'minimal' schema
#     attr_string :uid
#   end
# end
#
# See ::TypedSupport::ApiModelSchema for more details on the actual schema DSL
module TypedSupport
  class ApiSchema
    class << self
      def inherited(subclass)
        subclass.instance_variable_set(:@api_schema_klass, @api_schema_klass.clone)
        super
      end

      def schema(schema_name = :default, parent_schema = nil, &block)
        @api_schema_klass = {} if @api_schema_klass.nil?
        @api_schema_klass[schema_name] = Class.new(@api_schema_klass[schema_name] || ::TypedSupport::ApiModelSchema)
        @api_schema_klass[schema_name].instance_variable_set(:@def_block, block)
        @api_schema_klass[schema_name].instance_variable_set(:@klass_name, name)
        @api_schema_klass[schema_name].instance_variable_set(:@schema_name, schema_name)

        if parent_schema
          parent_block = @api_schema_klass[parent_schema].instance_variable_get(:@def_block)
          @api_schema_klass[schema_name].instance_eval(&parent_block)
        end
        @api_schema_klass[schema_name].instance_eval(&block)
      end

      attr_reader :api_schema_klass
    end

    def initialize(model)
      @model = model
    end

    def schema(name = :default, context = {})
      n = self.class.api_schema_klass[name].present? ? name : :default
      self.class.api_schema_klass[n].from_models({model: model}, {context: context})
    end

    attr_reader :model
  end
end
