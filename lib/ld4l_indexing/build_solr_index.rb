=begin
--------------------------------------------------------------------------------

Get all of the URIs for Agents, Instances, and Works.

Build a Solr document for each URI and add it to the Solr index.

--------------------------------------------------------------------------------

Usage: ld4l_build_solr_index source_site

--------------------------------------------------------------------------------
=end

module Ld4lIndexing
  class BuildSolrIndex
    USAGE_TEXT = 'Usage is ld4l_build_solr_index <source_site> <report_file> [REPLACE] [OVERWRITE] '

    QUERY_FIND_AGENTS = <<-END
      SELECT ?uri
      WHERE { 
        ?uri a <http://bibframe.org/vocab/Agent> . 
      }
    END
    QUERY_FIND_WORKS = <<-END
      SELECT ?uri
      WHERE { 
        ?uri <http://www.w3.org/1999/02/22-rdf-syntax-ns#type> <http://bibframe.org/vocab/Work> . 
      }
    END
    QUERY_FIND_INSTANCES = <<-END
      SELECT ?uri
      WHERE { 
        ?uri <http://www.w3.org/1999/02/22-rdf-syntax-ns#type> <http://bibframe.org/vocab/Instance> . 
      }
    END
    URI_BATCH_LIMIT = 1000
    #
    def initialize
    end

    def process_arguments(args)
      replace_file = args.delete('REPLACE')
      overwrite_index = args.delete('OVERWRITE')

      raise UserInputError.new(USAGE_TEXT) unless args && args.size == 2

      valid_source_sites = ['cornell', 'harvard', 'stanford']
      raise UserInputError.new("Source site must be one of these: #{valid_source_sites.join(', ')}") unless valid_source_sites.include?(args[0])
      @source_site = args[0]

      raise UserInputError.new("#{args[1]} already exists -- specify REPLACE") if File.exist?(args[1]) unless replace_file
      raise UserInputError.new("Can't create #{args[1]}: no parent directory.") unless Dir.exist?(File.dirname(args[1]))
      @report_file_path = File.expand_path(args[1])
    end

    def log_header(args)
      logit "ld4l_build_solr_index #{args.join(' ')}"
    end

    def logit(message)
      m = "#{Time.new.strftime('%Y-%m-%d %H:%M:%S')} #{message}"
      puts m
      @report.puts(m)
    end

    def report
      logit @doc_factory.instance_stats
      logit @doc_factory.work_stats
      logit @doc_factory.agent_stats
    end

    def prepare_solr()
      @ss = SolrServer.new('http://localhost:8983/solr/testing')
      raise UserInputError.new("#{@ss} is not running") unless @ss.running?
    end

    def prepare_triple_store()
      selected = TripleStoreController::Selector.selected
      raise UserInputError.new("No triple store selected.") unless selected

      TripleStoreDrivers.select(selected)
      @ts = TripleStoreDrivers.selected

      raise UserInputError.new("#{@ts} is not running") unless @ts.running?
    end

    def prepare_document_factory
      @doc_factory = DocumentFactory.new(@ts, :source_site => @source_site)
    end

    def index_agents()
      query_and_index_items(:agent, QUERY_FIND_AGENTS)
    end

    def index_instances()
      query_and_index_items(:instance, QUERY_FIND_INSTANCES)
    end

    def index_works()
      query_and_index_items(:work, QUERY_FIND_WORKS)
    end

    def query_and_index_items(type, query)
      UriDiscoverer.new(@ts, query, URI_BATCH_LIMIT).each do |uri|
        begin
          doc = @doc_factory.document(type, uri)
          @ss.add_document(doc.document) if doc
        rescue
          log_document_error(type, uri, doc, $!)
        end
      end
    end

    def log_document_error(type, uri, doc, error)
      doc_string = doc ? doc.document : "NO DOCUMENT FOR #{uri}"
      backtrace = error.backtrace.join("\n   ")
      logit "%s %s\n%s\n   %s" % [type, doc_string, error, backtrace]
    end

    def run()
      begin
        begin
          process_arguments(ARGV)
          @report = File.open(@report_file_path, 'w')

          log_header(ARGV)
          prepare_solr
          prepare_triple_store
          prepare_document_factory

          index_agents
          index_instances
          index_works

          report
        ensure
          @report.close if @report
        end
      rescue UserInputError
        puts
        puts "ERROR: #{$!}"
        puts
      end
    end
  end
end