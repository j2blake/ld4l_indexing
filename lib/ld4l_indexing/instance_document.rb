module Ld4lIndexing
  class IdentifierInfo
    attr_reader :localname
    attr_reader :value
    def initialize(type_uri, value)
      @localname = DocumentFactory::uri_localname(type_uri)
      @value = value
    end

    def to_token()
      "%s+++++%s" % [@localname, @value]
    end

    def to_string()
      "IdentifierInfo: %s: %s" % [@localname, @value]
    end
  end

  class InstanceDocument
    include DocumentBase

    NAMESPACE_WORLDCAT = 'http://www.worldcat.org/oclc/'
    PROP_INSTANCE_TITLE = 'http://bibframe.org/vocab/instanceTitle'
    PROP_INSTANCE_OF = 'http://bibframe.org/vocab/instanceOf'
    PROP_SYSTEM_NUMBER = 'http://bibframe.org/vocab/systemNumber'

    QUERY_INSTANCE_TITLE = <<-END
    PREFIX bf: <http://bibframe.org/vocab/>
    SELECT ?tstring ?st 
    WHERE {
      {
        ?i bf:title ?tstring .
      } UNION {
        ?i bf:instanceTitle ?t .
        ?t bf:titleValue ?tstring .
        OPTIONAL { ?t bf:subtitle ?st . }  
      } 
    } 
    END

    attr_reader :uri
    attr_reader :properties
    attr_reader :values
    attr_reader :document
    #
    def initialize(uri, ts, stats)
      @uri = uri
      @ts = ts
      @source_site = figure_source_site(uri)
      @stats = stats

      get_properties
      get_values
      assemble_document
      @stats.record(self)
    end

    def get_values()
      get_classes
      get_titles(QUERY_INSTANCE_TITLE)
      get_instance_of
      get_worldcat_ids
      @values = {'classes' => @classes, 'titles' => @titles, 'instance_of' => @instance_of, 'worldcat_ids' => @worldcat_ids}
    end

    def get_instance_of()
      @instance_of = []
      @properties.each do |prop|
        if prop['p'] == PROP_INSTANCE_OF
          @instance_of << prop['o']
        end
      end
    end

    def get_worldcat_ids
      @worldcat_ids = []
      @properties.each do |prop|
        if prop['p'] == PROP_SYSTEM_NUMBER
          if DocumentFactory::uri_namespace(prop['o']) == NAMESPACE_WORLDCAT
            @worldcat_ids << DocumentFactory::uri_localname(prop['o'])
          end
        end
      end
    end

    def assemble_document()
      doc = {}
      doc['id'] = DocumentFactory::uri_to_id(@uri)
      doc['title_display'] = @titles[0] unless @titles.empty?
      doc['alt_titles_t'] = @titles.drop(1) if @titles.size > 1
      doc['source_site_t'] = @source_site if @source_site
      doc['class_t'] = @classes unless @classes.empty?
      doc['instance_of_token'] = @instance_of.map { |uri| "%s+++++%s" % [get_label(uri), DocumentFactory::uri_to_id(uri)] }
      doc['worldcat_id_token'] = @worldcat_ids
      doc['text'] = @titles
      @document = doc
    end

  end
end
