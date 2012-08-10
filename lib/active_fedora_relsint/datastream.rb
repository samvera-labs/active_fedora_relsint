module ActiveFedora
  module RelsInt
    class Datastream < ActiveFedora::Datastream
      attr_accessor :relationships_loaded
      def serialize!
        self.content = to_rels_int() if changed_attributes.include? 'relationships'
        changed_attributes.delete 'relationships'
      end
      
      def relationships_will_change!
        changed_attributes['relationships'] = nil
      end
      
      def content
        if self.new? and @content.nil?
          content=ActiveFedora::RelsInt::Datastream.xml_template
        else
          super
        end
      end
      
      def content= new_content
        super
        relationships_loaded=false
        load_relationships
      end
      
      def to_resource(object, literal=false)
        if object.is_a? ActiveFedora::Datastream
          RDF::URI.new("info:fedora/#{object.pid}/#{object.dsid}")
        elsif object.respond_to? :internal_uri
          RDF::URI.new(object.internal_uri)
        elsif object.is_a? RDF::Resource
          object
        elsif literal
          RDF::Literal.new(object)
        else
          RDF::URI.new(object.to_s)
        end
      end
      
      def to_predicate(arg)
        return :p if arg.nil?
        if arg.is_a? Symbol
          arg = ActiveFedora::Predicates.find_graph_predicate(arg)
        elsif arg.is_a? RDF::Resource
          arg
        else
          RDF::URI.new(arg.to_s)
        end
      end
      
      def build_statement(datastream, predicate, object, literal=false)
        subject = to_resource(datastream)
        predicate = to_predicate(predicate)
        object = to_resource(object,literal)
        RDF::Statement.new(subject,predicate,object)
      end
      
      def add_relationship(datastream, predicate, target, literal=false)
        stmt = build_statement(datastream, predicate, target, literal)
        graph.insert(stmt) unless graph.has_statement? stmt
        relationships_will_change!
      end
      
      def remove_relationship(datastream, predicate, target, literal=false)
        stmt = build_statement(datastream, predicate, target, literal)
        graph.delete(stmt)
        relationships_will_change!
      end
      
      def clear_relationship(datastream, predicate)
        graph.delete [to_resource(datastream), predicate, nil]
        relationships_will_change!
      end
      
      def relationships(*args)
        q_args = args.empty? ? [:s, :p, :o] : [to_resource(args.first), to_predicate(args[1]), (args[2] || :o)]
        query = RDF::Query.new do |query|
          query << q_args
        end
        query.execute(graph).map(&:to_hash).map do |hash|
          stmt = q_args.map {|k| hash[k] || k}
          RDF::Statement.new(*stmt)
        end
      end
      
      def load_relationships
        # load from content
        g = RDF::Graph.new
        RDF::RDFXML::Reader.new(content).each do |stmt|
          g << stmt
        end
        self.relationships_loaded = true
        changed_attributes.delete 'relationships'
        @graph = g
      end
      
      def graph
        @graph ||= load_relationships
      end
      
      def to_rels_int
        xml = ActiveFedora::RDFXMLWriter.buffer(:max_depth=>1) do |writer|
          writer.prefixes.merge! ActiveFedora::Predicates.predicate_namespaces
          writer.write_graph(graph)
        end
        xml
      end
      
      def self.xml_template
        "<rdf:RDF xmlns:rdf=\"http://www.w3.org/1999/02/22-rdf-syntax-ns#\"></rdf:RDF>"
      end
    end
  end
end
