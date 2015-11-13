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

    QUERY_LABEL = <<-END
    PREFIX rdf: <http://www.w3.org/1999/02/22-rdf-syntax-ns#>
    PREFIX bf:  <http://bibframe.org/vocab/>
    PREFIX madsrdf: <http://www.loc.gov/mads/rdf/v1#>
    SELECT ?label ?aap ?title ?alabel
    WHERE { 
      OPTIONAL { ?s rdf:label ?label . }
      OPTIONAL { ?s bf:title ?title . }
      OPTIONAL { 
        ?s bf:authorizedAccessPoint ?aap . 
        FILTER ( lang(?label) != "x-bf-hash" )
      } 
      OPTIONAL {
        ?s bf:hasAuthority ?a .
        ?a a madsrdf:Authority ;
           madsrdf:authoritativeLabel ?alabel .
      }
    } LIMIT 1000
    END
    #
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

    def get_titles(query_string)
      @titles = []
      title_values = QueryRunner.new(query_string).bind_uri('i', @uri).execute(@ts)
      title_values.each do |row|
        t = row['tstring']
        st = row['st']
        if t
          if st
            @titles << "%s: %s" % [t, st]
          else
            @titles << t
          end
        end
      end
    end

    # For the times when you just want to create a link to something, and you need a label
    def get_label(uri)
      results = QueryRunner.new(QUERY_LABEL).bind_uri('s', uri).execute(@ts)
      results.each do |row|
        label = row['label'] || row['aap'] || row['title'] || row['alabel']
        return label if label && !label.strip.empty?
      end
      return "NO LABEL"
    end
  end
end
