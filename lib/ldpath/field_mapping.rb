module Ldpath
  class FieldMapping
    attr_reader :name, :selector, :field_type

    def initialize(name:, selector:, field_type: nil, options: {})
      @name = name.to_s
      @selector = selector
      @field_type = field_type
      @options = options
    end

    def evaluate(program, uri, context, maintain_literals: false)
      case selector
      when Ldpath::Selector
        return to_enum(:evaluate, program, uri, context, maintain_literals: maintain_literals) unless block_given?

        selector.evaluate(program, uri, context, maintain_literals: maintain_literals).each do |value|
          yield transform_value(value, maintain_literals: maintain_literals)
        end
      when RDF::Literal
        Array(selector.canonicalize.object)
      else
        Array(selector)
      end
    end

    private

    def transform_value(value, maintain_literals: false)
      v = if value.is_a?(RDF::Literal) && !maintain_literals
            value.canonicalize.object
          else
            value
          end

      if field_type && !same_type(v, field_type)
        v_literal = RDF::Literal.new(v.to_s, datatype: field_type)
        maintain_literals ? v_literal : v_literal.canonicalize.object
      else
        v
      end
    end

    def same_type(object, field_type)
      case object
      when RDF::Literal
        object.comperable_datatype? field_type
      when RDF::URI
        field_type.to_s.end_with? 'anyURI'
      else
        false
      end
    end
  end
end
