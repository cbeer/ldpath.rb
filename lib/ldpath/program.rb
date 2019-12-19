# Parse and evaluate an ldpath program.
# @see https://kschiess.github.io/parslet/documentation.html Parslet Documentation
# @see https://marmotta.apache.org/ldpath/language.html LDPath Language Reference
module Ldpath
  class Program
    ParseError = Class.new StandardError

    class << self

      # Parse ldpath program and apply transforms.
      # @param program [String] the program to be parsed
      # @param transform_context [Hash] see parslet documentation for more info
      # @return [Ldpath::Program] instance of this class that can be evaluated on a graph
      def parse(program, transform_context = {})
        ast = transform.apply load(program), transform_context

        Ldpath::Program.new ast.compact, transform_context
      end

      # Load the ldpath program using the ldpath parser.
      # @param program [String] ldpath program
      # @raise [ParseError] exception raised if parse fails
      # @return [Hash, Array, Parslet::Slice] PORO (Plain old Ruby object) result tree
      # @example ldpath program (see spec/ldpath_program_spec.rb for a more details example program)
      #   @prefix dcterms : <http://purl.org/dc/terms/> ;
      #   title = dcterms:title :: xsd:string ;
      #   parent_title = dcterms:isPartOf / dcterms:title :: xsd:string ;
      #   int_value = <info:intProperty>[^^xsd:integer] :: xsd:integer ;
      def load(program)
        parser.parse(program, reporter: Parslet::ErrorReporter::Deepest.new)
      rescue Parslet::ParseFailed => e
        raise ParseError, e.parse_failure_cause.ascii_tree
      end

      private

      def transform
        Ldpath::Transform.new
      end

      def parser
        @parser ||= Ldpath::Parser.new
      end
    end

    attr_reader :mappings, :prefixes, :filters, :default_loader, :loaders
    def initialize(mappings, default_loader: Ldpath::Loaders::Direct.new, prefixes: {}, filters: [], loaders: {})
      @mappings ||= mappings
      @default_loader = default_loader
      @loaders = loaders
      @prefixes = prefixes
      @filters = filters

    end

    # Evaluate an ldpath program returning values extracted from the graph and dereferencing the subject
    # to get additional context unless limit_to_context==false.
    # @param uri [RDF::URI] subject URI for matching triples from the graph
    # @param context [RDF::Graph] the graph from which to extract values
    # @param limit_to_context [Boolean] if true, only draw values from the passed in context; otherwise, will make curl requests to gather additional context
    # @param maintain_literals [Boolean] if true, will return values that are RDF::Literals as RDF::Literals; otherwise, returns canonicalize form (e.g. String, Integer, etc.)
    # @return [Array<RDF::Literal, Object>] the extracted values based on the ldpath with values that can be of type RDF::URI, RDF::Literal, String, Integer, etc.,
    #   based on the value in the graph and the value of maintain_literals.
    def evaluate(uri, context: nil, limit_to_context: false, maintain_literals: false)
      result = Ldpath::Result.new(self, uri, context: context, limit_to_context: limit_to_context, maintain_literals: maintain_literals)
      unless filters.empty?
        return {} unless filters.all? { |f| f.evaluate(result, uri, result.context, maintain_literals: maintain_literals) }
      end

      result.to_hash
    end

    def load(uri)
      loader = loaders.find { |k, v| uri =~ k }&.last
      loader ||= default_loader

      loader.load(uri)
    end
  end
end
