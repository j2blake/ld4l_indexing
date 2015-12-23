module Ld4lIndexing
  class InstanceDocument
    include DocumentBase

    NAMESPACE_WORLDCAT = 'http://www.worldcat.org/oclc/'
    PROP_SAME_AS = 'http://www.w3.org/2002/07/owl#sameAs'

    PROP_INSTANCE_OF = 'http://ld4l.org/ontology/bib/isInstanceOf'
    PROP_IDENTIFIED_BY = 'http://ld4l.org/ontology/bib/identifiedBy'
    PROP_HAS_PROVISION = 'http://ld4l.org/ontology/bib/hasProvision'
    PROP_EXTENT = 'http://ld4l.org/ontology/bib/extent'
    PROP_DIMENSIONS = 'http://ld4l.org/ontology/bib/dimensions'
    PROP_ILLUSTRATION_NOTE = 'http://ld4l.org/ontology/bib/illustrationNote'
    PROP_SUPPLEMENTARY_CONTENT_NOTE = 'http://ld4l.org/ontology/bib/legacy/supplementaryContentNote'

    TYPE_IDENTIFIER = 'http://ld4l.org/ontology/bib/Identifier'

    QUERY_IDENTIFIER_CONTENTS = <<-END
      PREFIX rdf: <http://www.w3.org/1999/02/22-rdf-syntax-ns#>
      SELECT ?type ?value 
      WHERE {
        ?id a ?type .
        ?id rdf:value ?value .
      } LIMIT 1000
    END

    QUERY_PUBLISHER_PROVISION = <<-END
      PREFIX dc: <http://purl.org/dc/elements/1.1/>
      PREFIX ld4l: <http://ld4l.org/ontology/bib/>
      PREFIX prov: <http://www.w3.org/ns/prov#>
      PREFIX foaf: <http://xmlns.com/foaf/0.1/>
      SELECT ?agent_name, ?location_name, ?date 
      WHERE {
        ?provision a ld4l:PublisherProvision .
        OPTIONAL {
          ?provision dc:date ?date .
        }
        OPTIONAL {
          ?provision prov:agent ?agent .
          ?agent foaf:name ?agent_name .
        }
        OPTIONAL {
          ?provision prov:atLocation ?location .
          ?location foaf:name ?location_name .
        }
      } LIMIT 1000
    END

    QUERY_SHELF_MARK = <<-END
      PREFIX ld4l: <http://ld4l.org/ontology/bib/>
      PREFIX rdf: <http://www.w3.org/1999/02/22-rdf-syntax-ns#>
      SELECT  ?value
      WHERE {
        ?holding ld4l:isHoldingFor ?instance .
        ?holding ld4l:hasShelfMark ?sm .
        ?sm rdf:value ?value
      } LIMIT 1000
    END
    #
    def initialize(uri, ts, stats)
      @uri = uri
      @ts = ts
      @source_site = figure_source_site(uri)
      @stats = stats

      begin
        get_properties
        get_values
        assemble_document
        @stats.record(self)
      rescue
        raise DocumentError.new($!, self)
      end
    end

    def get_values()
      get_classes
      get_titles
      get_instance_of
      get_worldcat_ids_and_same_as
      get_identifiers
      get_publisher_provisions
      get_holdings
      get_data_properties
      @values = {
        'classes' => @classes,
        'titles' => @titles,
        'instance_of' => @instance_of,
        'worldcat_ids' => @worldcat_ids,
        'same_as' => @same_as,
        'identifiers' => @identifiers,
        'publishers' => @publishers,
        'holdings' => @holdings,
        'extent' => @extents,
        'dimensions' => @dimensions,
        'illustration_notes' => @illustration_notes,
        'supplementary_content_notes' => @supplementary_content_notes
      }
    end

    def get_instance_of()
      @instance_of = []
      @properties.each do |prop|
        if prop['p'] == PROP_INSTANCE_OF
          uri = prop['o']
          @instance_of << { uri: uri, label: get_titles_for(uri).shift, id: DocumentFactory::uri_to_id(uri) }
        end
      end
    end

    def get_worldcat_ids_and_same_as()
      @worldcat_ids = []
      @same_as = []
      @properties.each do |prop|
        if prop['p'] == PROP_SAME_AS
          if prop['o'].start_with?(NAMESPACE_WORLDCAT)
            @worldcat_ids << prop['o']
          else
            @same_as << prop['o']
          end
        end
      end
    end

    def get_identifiers()
      @identifiers = []
      @properties.each do |prop|
        if prop['p'] == PROP_IDENTIFIED_BY
          results = QueryRunner.new(QUERY_IDENTIFIER_CONTENTS).bind_uri('id', prop['o']).execute(@ts)
          types = []
          value = nil
          results.each do |row|
            value = row['value']
            types << row['type']
          end
          types.delete(TYPE_IDENTIFIER)
          @identifiers << { localname: DocumentFactory::uri_localname(types.shift || TYPE_IDENTIFIER), label: value} if value
        end
      end
    end

    def get_publisher_provisions()
      @publishers = []
      @properties.each do |prop|
        if prop['p'] == PROP_HAS_PROVISION
          results = QueryRunner.new(QUERY_PUBLISHER_PROVISION).bind_uri('provision', prop['o']).execute(@ts)
          results.each do |row|
            parts = []
            parts << row['agent_name'] if row['agent_name']
            parts << row['location_name'] if row['location_name']
            parts << row['date'] if row['date']
            @publishers << parts.join(', ') unless parts.empty?
          end
        end
      end
    end

    def get_holdings()
      results = QueryRunner.new(QUERY_SHELF_MARK).bind_uri('instance', @uri).execute(@ts)
      @holdings = results.each.map {|row| row['value'] }.select{|v| v}
    end

    def get_data_properties()
      @extents = []
      @dimensions = []
      @illustration_notes = []
      @supplementary_content_notes = []
      @properties.each do |prop|
        @extents << prop['o'] if prop['p'] == PROP_EXTENT
        @dimensions << prop['o'] if prop['p'] == PROP_DIMENSIONS
        @illustration_notes << prop['o'] if prop['p'] == PROP_ILLUSTRATION_NOTE
        @supplementary_content_notes << prop['o'] if prop['p'] == PROP_SUPPLEMENTARY_CONTENT_NOTE
      end
    end

    def assemble_document()
      doc = {}
      doc['id'] = DocumentFactory::uri_to_id(@uri)
      doc['uri_token'] = @uri
      doc['category_facet'] = "Instance"
      doc['title_display'] = @titles[0] unless @titles.empty?
      doc['alt_titles_t'] = @titles.drop(1) if @titles.size > 1
      doc['source_site_facet'] = @source_site if @source_site
      doc['source_site_display'] = @source_site if @source_site
      doc['class_display'] = @classes unless @classes.empty?
      doc['class_facet'] = @classes.reject {|c| c == 'Instance'} unless @classes.empty?
      doc['instance_of_token'] = @instance_of.map { |i| i.to_json} unless @instance_of.empty?
      doc['worldcat_id_token'] = @worldcat_ids unless @worldcat_ids.empty?
      doc['same_as_token'] = @same_as unless @same_as.empty?
      doc['identifier_token'] = @identifiers.map {|i| i.to_json} unless @identifiers.empty?
      doc['publisher_t'] = @publishers unless @publishers.empty?
      doc['holding_t'] = @holdings unless @holdings.empty?
      doc['extent_t'] = @extents unless @extents.empty?
      doc['dimensions_t'] = @dimensions unless @dimensions.empty?
      doc['illustration_note_t'] = @illustration_notes unless @illustration_notes.empty?
      doc['supplementary_content_note_t'] = @supplementary_content_notes unless @supplementary_content_notes.empty?
      doc['text'] = @titles
      @document = doc
    end

  end
end
