module Ld4lIndexing
  module DocumentBase
    PROP_TITLE_VALUE = 'http://bibframe.org/vocab/titleValue'
    PROP_RDFS_TYPE = 'http://www.w3.org/1999/02/22-rdf-syntax-ns#type'

    QUERY_PROPERTIES = <<-END
      SELECT ?p ?o
      WHERE { 
        ?s ?p ?o . 
      } LIMIT 1000
    END

    QUERY_TITLE = <<-END
      PREFIX ld4l: <http://bib.ld4l.org/ontology/>
      PREFIX rdfs: <http://www.w3.org/2000/01/rdf-schema#>
      SELECT ?title
      WHERE {
        {
          ?i ld4l:hasTitle ?t .
          ?t rdfs:label ?title .
        } 
      } LIMIT 100
    END

    attr_reader :uri
    attr_reader :properties
    attr_reader :values
    attr_reader :document
    #
    def figure_source_site(uri)
      DocumentFactory::GRAPH_NAMES.each_pair do |site, graph|
        if uri.start_with? graph
          return site.capitalize
        end
      end
      nil
    end

    def get_properties()
      @properties = QueryRunner.new(QUERY_PROPERTIES).bind_uri('s', @uri).execute(@ts)
    end

    def get_classes
      @classes = []
      @properties.each do |prop|
        if prop['p'] == PROP_RDFS_TYPE
          localname = DocumentFactory::uri_localname(prop['o'])
          @classes << localname if localname
        end
      end
    end

    def get_titles()
      @titles = get_titles_for(@uri)
    end

    def get_titles_for(uri)
      titles = []
      values = QueryRunner.new(QUERY_TITLE).bind_uri('i', uri).execute(@ts)
      values.each do |row|
        titles << row['title'] if row['title']
      end
      if titles.empty?
        titles << 'NO TITLE'
        if uri == @uri
          @stats.warning 'NO TITLE'
        else
          @stats.warning 'NO TITLE for uri'
        end
      end
      titles
    end

    def get_site_name(uri)
      uri.split('/')[-2].capitalize
    end
  end
end
