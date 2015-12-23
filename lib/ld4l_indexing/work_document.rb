module Ld4lIndexing
  class WorkDocument
    include DocumentBase

    LOCAL_URI_PREFIX = 'http://draft.ld4l.org/'

    QUERY_WORK_TOPIC = <<-END
      PREFIX ld4l: <http://ld4l.org/ontology/bib/>
      PREFIX dcterms: <http://purl.org/dc/terms/>
      PREFIX skos: <http://www.w3.org/2004/02/skos/core#>
      PREFIX foaf: <http://xmlns.com/foaf/0.1/>
      SELECT ?topic ?label ?type
      WHERE {
        ?work dcterms:subject ?topic .
        OPTIONAL { 
          ?topic skos:prefLabel ?label 
          BIND('topic' as ?type) 
        }
        OPTIONAL { 
          ?topic foaf:name ?label 
          BIND('person' as ?type) 
        }
      } LIMIT 1000
    END

    QUERY_INSTANCES_OF_WORK = <<-END
    PREFIX ld4l: <http://ld4l.org/ontology/bib/>
    SELECT ?instance 
    WHERE {
      ?instance ld4l:isInstanceOf ?work .
    } LIMIT 1000
    END

    QUERY_CONTRIBUTORS = <<-END
      PREFIX ld4l: <http://ld4l.org/ontology/bib/>
      PREFIX foaf: <http://xmlns.com/foaf/0.1/>
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
      SELECT ?lang ?label
      WHERE { 
        ?w dc:language ?lang .
        OPTIONAL {
          ?lang rdfs:label ?label .
        }
      } LIMIT 1000
    END

    QUERY_EXTENT_OF_INSTANCE = <<-END
      PREFIX ld4l: <http://ld4l.org/ontology/bib/>
      SELECT ?extent 
      WHERE { 
        ?i ld4l:extent ?extent .
      } LIMIT 1000
    END

    QUERY_RELATED_WORKS = <<-END
      PREFIX ld4l: <http://ld4l.org/ontology/bib/>
      SELECT ?p ?related 
      WHERE { 
        ?w ?p ?related .
        ?related a ld4l:Work
      } LIMIT 10000
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
      rescue
        raise DocumentError.new($!, self)
      end
      @stats.record(self)
    end

    def get_values
      get_classes
      get_titles
      get_topics
      get_instances
      get_creators_and_contributors
      get_languages
      get_related_works
      @values = {
        'classes' => @classes,
        'titles' => @titles,
        'topics' => @topics,
        'instances' => @instances,
        'creators' => @creators,
        'contributors' => @contributors,
        'languages' => @languages,
        'related' => @related,
      }
    end

    def get_topics
      @topics = []
      results = QueryRunner.new(QUERY_WORK_TOPIC).bind_uri('work', @uri).execute(@ts)
      results.each do |row|
        if row['topic']
          t = row['topic']
          topic = {}
          topic[:label] = row['label'] || DocumentFactory.uri_localname(t)
          topic[:uri] = t 
          topic[:id] = DocumentFactory.uri_to_id(t) if t.start_with?(LOCAL_URI_PREFIX)
          topic[:type] = row['type'] if row['type']
          @topics << topic
        end
      end
    end

    def get_instances()
      @instances = []
      results = QueryRunner.new(QUERY_INSTANCES_OF_WORK).bind_uri('work', @uri).execute(@ts)
      results.each do |row|
        instance_uri = row['instance']
        if (instance_uri)
          extent = get_extent_for_instance(instance_uri)
          instance = {}
          instance[:uri] = instance_uri
          instance[:label] = get_titles_for(instance_uri).shift
          instance[:id] = DocumentFactory::uri_to_id(instance_uri)
          instance[:extent] = extent if extent
          @instances << instance
        end
      end
    end

    def get_extent_for_instance(instance_uri)
      results = QueryRunner.new(QUERY_EXTENT_OF_INSTANCE).bind_uri('i', instance_uri).execute(@ts)
      if results.empty?
        nil
      else
        results[0]['extent']
      end
    end

    def get_creators_and_contributors()
      @creators = []
      @contributors = []
      results = QueryRunner.new(QUERY_CONTRIBUTORS).bind_uri('w', @uri).execute(@ts)
      results.each do |row|
        name = row['name'] || 'NO NAME'
        if row['agent']
          agent_uri = row['agent']
          if row['isAuthor']
            @creators << {uri: agent_uri, label: name, id: DocumentFactory::uri_to_id(agent_uri)}
          else
            @contributors << {uri: agent_uri, label: name, id: DocumentFactory::uri_to_id(agent_uri)}
          end
        end
      end
    end

    def get_languages()
      @languages = []
      results = QueryRunner.new(QUERY_LANGUAGES).bind_uri('w', @uri).execute(@ts)
      results.each do |row|
        if row['lang']
          @languages << row['label'] || LanguageReference.lookup(row['lang']) || DocumentFactory.uri_localname(row['lang'])
        end
      end
    end

    def get_related_works()
      @related = []
      results = QueryRunner.new(QUERY_RELATED_WORKS).bind_uri('w', @uri).execute(@ts)
      results.each do |row|
        uri = row['related']
        related = {}
        related['uri'] = uri,
        related['property'] = row['p'],
        related['label'] = get_titles_for(uri).shift
        related['id'] = DocumentFactory::uri_to_id(uri) if uri.start_with?(LOCAL_URI_PREFIX)
        @related << related
      end
    end

    def assemble_document()
      doc = {}
      doc['id'] = DocumentFactory::uri_to_id(@uri)
      doc['uri_token'] = @uri
      doc['category_facet'] = "Work"
      doc['title_display'] = @titles[0] unless @titles.empty?
      doc['alt_titles_t'] = @titles.drop(1) if @titles.size > 1
      doc['source_site_facet'] = @source_site if @source_site
      doc['source_site_display'] = @source_site if @source_site
      doc['class_display'] = @classes unless @classes.empty?
      doc['class_facet'] = @classes.reject {|c| c == 'Work'} unless @classes.empty?
      doc['language_display'] = @languages unless @languages.empty?
      doc['language_facet'] = @languages unless @languages.empty?
      doc['subject_token'] = @topics.map {|t| t.to_json} unless @topics.empty?
      doc['subject_topic_facet'] = @topics.map {|t| t[:label]} unless @topics.empty?
      doc['instance_token'] = @instances.map {|i| i.to_json}
      doc['creator_token'] = @creators.map {|c| c.to_json} unless @creators.empty?
      doc['contributor_token'] = @contributors.map {|c| c.to_json} unless @contributors.empty?
      doc['related_works_token'] = @related.map {|r| r.to_json} unless @related.empty?
      doc['text'] = @titles + (@topics + @creators + @contributors).map {|t| t[:label]}
      @document = doc
    end

  end
end