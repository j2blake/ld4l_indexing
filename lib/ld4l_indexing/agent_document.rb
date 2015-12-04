module Ld4lIndexing
  class WorkInfo
    attr_reader :uri
    attr_reader :title
    def initialize(uri, title)
      @uri = uri
      @title = title
    end

    def to_token()
      "%s+++++%s" % [@title, DocumentFactory::uri_to_id(@uri)]
    end

    def to_string()
      "Work: %s %s" %[@title, @uri]
    end
  end

  class AgentDocument
    include DocumentBase
    
    PROP_NAME = 'http://http://xmlns.com/foaf/0.1/name'
    PROP_BIRTHDATE = 'http://schema.org/birthDate'

    QUERY_CONTRIBUTIONS = <<-END
      PREFIX ld4l: <http://ld4l.org/ontology/bib/>
      PREFIX prov: <http://www.w3.org/ns/prov#>
      PREFIX rdfs: <http://www.w3.org/2000/01/rdf-schema#>
      SELECT ?work ?title ?isAuthor 
      WHERE { 
        ?work ld4l:hasContribution ?c .
        ?c prov:agent ?agent .
        OPTIONAL {
          ?work ld4l:hasTitle ?t .
          ?t rdfs:label ?title .
        }
        OPTIONAL { 
          ?c a ld4l:AuthorContribution . 
          BIND(?c as ?isAuthor) 
        }
      } LIMIT 1000
    END

    attr_reader :uri
    attr_reader :properties
    attr_reader :values
    attr_reader :document
    #
    def initialize(uri, ts, source_site, stats)
      $stdout.write('A')
      #      puts "building Agent #{uri}"
      @uri = uri
      @ts = ts
      @source_site = source_site
      @stats = stats

      get_properties
      get_values
      assemble_document
      @stats.record(self)
    end

    def get_values()
      get_classes
      get_names
      get_birthdate
      get_created_and_contributed
      @values = {
        'classes' => @classes,
        'names' => @names ,
        'created' => @created,
        'contributed' => @contributed,
        'birthdate' => @birthdate,
      }
    end

    def get_names()
      @names = @properties.select {|prop| prop['p'] == PROP_NAME }.map {|prop| prop['o']}
    end

    def get_birthdate()
      @birthdate = @properties.select {|prop| prop['p'] == PROP_BIRTHDATE }.map {|prop| prop['o']}
    end

    def get_created_and_contributed
      @created = []
      @contributed = []
      results = QueryRunner.new(QUERY_CONTRIBUTIONS).bind_uri('agent', @uri).execute(@ts)
      results.each do |row|
        title = row['title'] || 'NO TITLE'
        if row['work']
          if row['isAuthor']
            @created << WorkInfo.new(row['work'], title)
          else
            @contributed << WorkInfo.new(row['work'], title)
          end
        end
      end
    end

    def assemble_document()
      doc = {}
      doc['id'] = DocumentFactory::uri_to_id(@uri)
      doc['title_display'] = @names[0] unless @names.empty?
      doc['alt_names_t'] = @names.drop(1) if @names.size > 1
      doc['source_site_facet'] = @source_site if @source_site
      doc['class_facet'] = @classes unless @classes.empty?
      doc['birthdate_t'] = @birthdate.shift unless @birthdate.empty?
      doc['created_token'] = @created.map {|w| w.to_token} unless @created.empty?
      doc['contributed_token'] = @contributed.map {|w| w.to_token} unless @contributed.empty?
      doc['text'] = @names + @created.map {|w| w.title} + @contributed.map {|w| w.title}
      @document = doc
    end
  end
end