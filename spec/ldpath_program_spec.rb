require 'spec_helper'

describe Ldpath::Program do
  describe "Simple program" do
    subject do
      Ldpath::Program.parse <<-EOF
@prefix dcterms : <http://purl.org/dc/terms/> ;
title = dcterms:title :: xsd:string ;
parent_title = dcterms:isPartOf / dcterms:title :: xsd:string ;
titles = dcterms:title | (dcterms:isPartOf / dcterms:title) | (^dcterms:isPartOf / dcterms:title) :: xsd:string ;
no_titles = dcterms:title & (dcterms:isPartOf / dcterms:title) & (^dcterms:isPartOf / dcterms:title) :: xsd:string ;
self = . :: xsd:string ;
wildcard = * ::xsd:string ;
child_title = ^dcterms:isPartOf / dcterms:title :: xsd:string ;
recursive = (dcterms:isPartOf)* ;
en_description = dcterms:description[@en] ;
conditional = dcterms:isPartOf[dcterms:title] ;
conditional_false = dcterms:isPartOf[dcterms:description] ;
EOF
    end
    
    let(:object) { RDF::URI.new("info:a") }
    let(:parent) { RDF::URI.new("info:b") }
    let(:child) { RDF::URI.new("info:c") }
    let(:grandparent) { RDF::URI.new("info:d") }
    
    let(:graph) do
      RDF::Graph.new
    end
    
    it "should work" do
      graph << [object, RDF::DC.title, "Hello, world!"]
      graph << [object, RDF::DC.isPartOf, parent]
      graph << [object, RDF::DC.description,  RDF::Literal.new("English!", language: "en")]
      graph << [object, RDF::DC.description,  RDF::Literal.new("French!", language: "fr")]
      graph << [parent, RDF::DC.title, "Parent title"]
      graph << [child, RDF::DC.isPartOf, object]
      graph << [child, RDF::DC.title, "Child title"]
      graph << [parent, RDF::DC.isPartOf, grandparent]
      result = subject.evaluate object, graph

      expect(result["title"]).to match_array "Hello, world!"
      expect(result["parent_title"]).to match_array "Parent title"
      expect(result["self"]).to match_array(object)
      expect(result["wildcard"]).to include "Hello, world!", parent
      expect(result["child_title"]).to match_array "Child title"
      expect(result["titles"]).to match_array ["Hello, world!", "Parent title", "Child title"]
      expect(result["no_titles"]).to be_empty
      expect(result["recursive"]).to match_array [parent, grandparent]
      expect(result["en_description"].first.to_s).to eq "English!"
      expect(result["conditional"]).to match_array parent
      expect(result["conditional_false"]).to be_empty
    end
  end
end