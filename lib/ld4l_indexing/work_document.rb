module Ld4lIndexing
  class WorkDocument
    include DocumentBase

    QUERY_WORK_TITLE = <<-END
    PREFIX bf: <http://bibframe.org/vocab/>
    SELECT ?tstring ?st 
    WHERE {
      {
        ?i bf:title ?tstring .
      } UNION {
        ?i bf:workTitle ?t .
        ?t bf:titleValue ?tstring .
        OPTIONAL { ?t bf:subtitle ?st . }  
      } 
    } LIMIT 100
    END

    QUERY_WORK_TOPIC = <<-END
    PREFIX bf: <http://bibframe.org/vocab/>
    PREFIX madsrdf: <http://www.loc.gov/mads/rdf/v1#>
    SELECT ?topic ?aap_topic ?label_topic ?auth_topic ?fasturi 
    WHERE {
      ?work bf:subject ?topic .
      OPTIONAL { ?topic bf:authorizedAccessPoint ?aap_topic . }
      OPTIONAL { ?topic bf:label ?label_topic . }
      OPTIONAL {
        ?topic bf:hasAuthority ?authority .
        ?authority a madsrdf:Authority ;
        madsrdf:authoritativeLabel ?auth_topic .
      }
      OPTIONAL {
        ?topic bf:systemNumber ?identifier .
        ?identifier bf:identifierValue ?fast .
        FILTER regex(?fast, "(OColC)fst" )
        BIND ( IRI ( CONCAT (" http://id.worldcat.org/fast/", REPLACE(?fast, "(OColC)fst", "" ) ) ) AS ?fasturi )
      }
    } LIMIT 100
    END

    QUERY_INSTANCES_OF_WORK = <<-END
    PREFIX bf: <http://bibframe.org/vocab/>
    SELECT ?instance 
    WHERE {
      ?instance bf:instanceOf ?work .
    } LIMIT 100
    END

    QUERY_CREATORS = <<-END
    PREFIX bf: <http://bibframe.org/vocab/>
    SELECT ?c 
    WHERE { 
      ?w bf:creator ?c .
    }
    END

    QUERY_CONTRIBUTORS = <<-END
    PREFIX bf: <http://bibframe.org/vocab/>
    SELECT ?c 
    WHERE { 
      ?w bf:contributor ?c .
    }
    END

    attr_reader :uri
    attr_reader :properties
    attr_reader :values
    attr_reader :document
    #
    def initialize(uri, ts, source_site, stats)
      @uri = uri
      @ts = ts
      @source_site = source_site
      @stats = stats

      get_properties
      get_values
      assemble_document
      @stats.record(self)
    end

    def get_values
      get_classes
      get_titles(QUERY_WORK_TITLE)
      get_topics
      get_instances
      get_creators
      get_contributors
      @values = {
        'classes' => @classes,
        'titles' => @titles,
        'topics' => @topics,
        'instance_uris' => @instance_uris,
        'creators' => @creators,
        'contributors' => @contributors  }
    end

    def get_topics
      @topics = []
      @fast_uris = []
      results = QueryRunner.new(QUERY_WORK_TOPIC).bind_uri('work', @uri).execute(@ts)
      results.each do |row|
        t = row['aap_topic'] || row['label_topic'] || row['auth_topic']
        @topics << t if t
        f = row['fasturi']
        @fast_uris << f if f
      end
    end

    def get_instances()
      @instance_uris = []
      results = QueryRunner.new(QUERY_INSTANCES_OF_WORK).bind_uri('work', @uri).execute(@ts)
      results.each do |row|
        @instance_uris << row['instance'] if row['instance']
      end
    end

    def get_creators()
      @creators = []
      results = QueryRunner.new(QUERY_CREATORS).bind_uri('w', @uri).execute(@ts)
      results.each do |row|
        @creators << row['c'] if row['c']
      end
    end

    def get_contributors()
      @contributors = []
      results = QueryRunner.new(QUERY_CONTRIBUTORS).bind_uri('w', @uri).execute(@ts)
      results.each do |row|
        @contributors << row['c'] if row['c']
      end
    end

    def assemble_document()
      doc = {}
      doc['id'] = DocumentFactory::uri_to_id(@uri)
      doc['title_display'] = @titles[0] unless @titles.empty?
      doc['alt_titles_t'] = @titles.drop(1) if @titles.size > 1
      doc['source_site_t'] = @source_site if @source_site
      doc['class_t'] = @classes unless @classes.empty?
      doc['subject_topic_facet'] = @topics unless @topics.empty?
      doc['fasturi_t'] = @fast_uris unless @fast_uris.empty?
      doc['instance_token'] = @instance_uris.map { |uri| "%s+++++%s" % [get_label(uri), DocumentFactory::uri_to_id(uri)] }
      doc['creator_token'] = @creators.map { |uri| "%s+++++%s" % [get_label(uri), DocumentFactory::uri_to_id(uri)] }
      doc['contributor_token'] = @contributors.map { |uri| "%s+++++%s" % [get_label(uri), DocumentFactory::uri_to_id(uri)] }
      doc['text'] = @titles.concat(@topics)
      @document = doc
    end

  end
end