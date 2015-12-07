module Ld4lIndexing
  class DocumentFactory
    GRAPH_NAMES = {
      'cornell' => 'http://draft.ld4l.org/cornell',
      'harvard' => 'http://draft.ld4l.org/harvard',
      'stanford' => 'http://draft.ld4l.org/stanford',
    }

    attr_reader :instance_stats
    attr_reader :work_stats
    attr_reader :agent_stats

    class << self
      def uri_localname(uri)
        delimiter = uri.rindex(/[\/#]/)
        if delimiter
          uri[delimiter+1..-1]
        else
          uri
        end
      end

      def uri_namespace(uri)
        delimiter = uri.rindex(/[\/#]/)
        if delimiter
          uri[0..delimiter]
        else
          ''
        end
      end

      def uri_to_id(uri)
        uri.unpack('H*')[0]
      end
    end

    def initialize(ts)
      @ts = ts
      @instance_stats = DocumentStatsAccumulator.new("INSTANCES")
      @work_stats = DocumentStatsAccumulator.new("WORKS")
      @agent_stats = DocumentStatsAccumulator.new("AGENTS")
    end

    def document(type, uri)
      case type
      when :agent
        agent_document(uri)
      when :instance
        instance_document(uri)
      when :work
        work_document(uri)
      else
        raise "Invalid document type: #{type}"
      end
    end

    def instance_document(uri)
      InstanceDocument.new(uri, @ts, @instance_stats)
    end

    def work_document(uri)
      WorkDocument.new(uri, @ts, @work_stats)
    end

    def agent_document(uri)
      AgentDocument.new(uri, @ts, @agent_stats)
    end

    def counts()
      [@instance_stats.docs_count, @work_stats.docs_count, @agent_stats.docs_count]
    end
  end
end