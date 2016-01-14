=begin

At startup, load the topics file.

When requested, find the English-language label of a topic instance.
If not found, return nil.

We're looking for a statement like this:
<http://id.loc.gov/vocabulary/geographicAreas/n> <http://www.w3.org/2000/01/rdf-schema#label> "North America"@en .

[Shares a lot of code with Ld4lIndexing::LanguageReference]

=end

module Ld4lIndexing
  class TopicReference
    class << self
      begin
        @@graph = RDF::Graph.load(File.join(File.dirname(__FILE__), '..', '..', 'data', 'topic_labels.nt'))
        @@label = RDF::URI.new('http://www.w3.org/2000/01/rdf-schema#label')
      end

      def lookup(topic_uri)
        query = RDF::Query.new do
          pattern [RDF::URI.new(topic_uri), @@label, :label]
        end

        query.execute(@@graph).each do |solution|
          label = solution[:label]
          return label.value if label.language.to_s == 'en'
        end

        nil
      end
    end
  end
end
