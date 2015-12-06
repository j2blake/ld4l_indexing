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

    QUERY_AGENT_CREATES = <<-END
    PREFIX bf: <http://bibframe.org/vocab/>
    SELECT ?w 
    WHERE {
      ?w bf:creator ?a .
    } LIMIT 100
    END

    QUERY_AGENT_CONTRIBUTES = <<-END
    PREFIX bf: <http://bibframe.org/vocab/>
    SELECT ?w 
    WHERE {
      ?w bf:contributor ?a .
    } LIMIT 100
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
      get_created
      get_contributed
      @values = {
        'classes' => @classes,
        'names' => @names ,
        'created' => @created,
        'contributed' => @contributed }
    end

    def get_names()
      @names = [get_label(@uri)]
    end

    def get_created()
      results = QueryRunner.new(QUERY_AGENT_CREATES).bind_uri('a', @uri).execute(@ts)
      @created = results.map { |row| row['w'] }.select {|w| w && !w.strip.empty? }
    end

    def get_contributed()
      results = QueryRunner.new(QUERY_AGENT_CONTRIBUTES).bind_uri('a', @uri).execute(@ts)
      @contributed = results.map { |row| row['w'] }.select {|w| w && !w.strip.empty? }
    end

    def assemble_document()
      doc = {}
      doc['id'] = DocumentFactory::uri_to_id(@uri)
      doc['title_display'] = @names[0] unless @names.empty?
      doc['alt_titles_t'] = @names.drop(1) if @names.size > 1
      doc['source_site_t'] = @source_site if @source_site
      doc['class_t'] = @classes unless @classes.empty?
      doc['created_token'] = @created.map { |uri| "%s+++++%s" % [get_label(uri), DocumentFactory::uri_to_id(uri)] }
      doc['contributed_token'] = @contributed.map { |uri| "%s+++++%s" % [get_label(uri), DocumentFactory::uri_to_id(uri)] }
      doc['text'] = @names
      @document = doc
    end
  end
end