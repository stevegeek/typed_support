# frozen_string_literal: true

module TypedSupport
  module WithApiSchema
    def to_api(name = :default, context = {}, schema_namespace = "::Api::Schemas")
      schema_klass = "#{schema_namespace}::#{self.class.name}".safe_constantize
      schema_klass.new(self).schema(name, context)
    end
  end
end
