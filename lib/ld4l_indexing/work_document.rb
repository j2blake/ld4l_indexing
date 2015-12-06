module Ld4lIndexing
  class AgentInfo
    attr_reader :uri
    attr_reader :name
    def initialize(uri, name)
      @uri = uri
      @name = name
    end

    def to_token()
      "%s+++++%s" % [@name, DocumentFactory::uri_to_id(@uri)]
    end

    def to_string()
      "Agent: %s %s" % [@name, @uri]
    end
  end

  class Topic
    LOCAL_URI_PREFIX = 'http://draft.ld4l.org/'
    attr_reader :uri
    attr_reader :label
    def initialize(uri, label)
      @uri = uri
      @label = label
    end

    def to_token()
      if @uri.start_with?(LOCAL_URI_PREFIX)
        @label
      else
        "%s+++++%s" % [@label, @uri]
      end
    end

    def to_string()
      "Topic: %s %s" %[@label, @uri]
    end
  end

  class WorkDocument
    include DocumentBase

    QUERY_WORK_TOPIC = <<-END
      PREFIX ld4l: <http://ld4l.org/ontology/bib/>
      PREFIX skos: <http://www.w3.org/2004/02/skos/core#>
      SELECT ?topic ?label
      WHERE {
        ?work ld4l:subject ?topic .
        OPTIONAL { 
          ?topic skos:prefLabel ?label 
        }
      } LIMIT 1000
    END

    QUERY_INSTANCES_OF_WORK = <<-END
    PREFIX ld4l: <http://ld4l.org/ontology/bib/>
    SELECT ?instance 
    WHERE {
      ?instance ld4l:instanceOf ?work .
    } LIMIT 1000
    END

    QUERY_CONTRIBUTORS = <<-END
      PREFIX ld4l: <http://ld4l.org/ontology/bib/>
      PREFIX foaf: <http://http://xmlns.com/foaf/0.1/>
      PREFIX prov: <http://www.w3.org/ns/prov#>
      SELECT ?agent ?name ?isAuthor 
      WHERE { 
        ?w ld4l:hasContribution ?c .
        ?c prov:agent ?agent .
        OPTIONAL {
          ?agent foaf:name ?name .
        }
        OPTIONAL { 
          ?c a ld4l:AuthorContribution . 
          BIND(?c as ?isAuthor) 
        }
      } LIMIT 1000
    END

    QUERY_LANGUAGES = <<-END
      PREFIX dc: <http://purl.org/dc/terms/>
      SELECT ?lang 
      WHERE { 
        ?w dc:language ?lang .
      } LIMIT 1000
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
      get_titles
      get_topics
      get_instances
      get_creators_and_contributors
      get_languages
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
      results = QueryRunner.new(QUERY_WORK_TOPIC).bind_uri('work', @uri).execute(@ts)
      results.each do |row|
        if row['topic']
          if row['label']
            @topics << Topic.new(row['topic'], row['label'])
          else
            @topics << Topic.new(row['topic'], 'NO LABEL')
          end
        end
      end
    end

    def get_instances()
      @instance_uris = []
      results = QueryRunner.new(QUERY_INSTANCES_OF_WORK).bind_uri('work', @uri).execute(@ts)
      results.each do |row|
        @instance_uris << row['instance'] if row['instance']
      end
    end

    def get_creators_and_contributors()
      @creators = []
      @contributors = []
      results = QueryRunner.new(QUERY_CONTRIBUTORS).bind_uri('w', @uri).execute(@ts)
      results.each do |row|
        name = row['name'] || 'NO NAME'
        if row['agent']
          if row['isAuthor']
            @creators << AgentInfo.new(row['agent'], name)
          else
            @contributors << AgentInfo.new(row['agent'], name)
          end
        end
      end
    end

    def get_languages()
      @languages = []
      results = QueryRunner.new(QUERY_LANGUAGES).bind_uri('w', @uri).execute(@ts)
      results.each do |row|
        if row['lang']
          @languages << (LanguageReference.lookup(row['lang']) || DocumentFactory.uri_localname(row['lang']))
        end
      end
    end

    def assemble_document()
      doc = {}
      doc['id'] = DocumentFactory::uri_to_id(@uri)
      doc['title_display'] = @titles[0] unless @titles.empty?
      doc['alt_titles_t'] = @titles.drop(1) if @titles.size > 1
      doc['source_site_facet'] = @source_site if @source_site
      doc['class_facet'] = @classes unless @classes.empty?
      doc['language_display'] = @languages unless @languages.empty?
      doc['language_facet'] = @languages unless @languages.empty?
      doc['subject_token'] = @topics.map {|t| t.to_token} unless @topics.empty?
      doc['subject_topic_facet'] = @topics.map {|t| t.label} unless @topics.empty?
      doc['instance_token'] = @instance_uris.map {|i| "%s+++++%s" % [get_titles_for(i).shift, DocumentFactory::uri_to_id(i)]}
      doc['creator_token'] = @creators.map {|c| c.to_token} unless @creators.empty?
      doc['contributor_token'] = @contributors.map {|c| c.to_token} unless @contributors.empty?
      doc['text'] = @titles + (@topics.map {|t| t.label}) + (@creators.map {|c| c.name}) + (@contributors.map {|c| c.name})
      @document = doc
    end

  end
end