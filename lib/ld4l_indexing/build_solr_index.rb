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
      SELECT ?s
      WHERE { 
        ?s a <http://bibframe.org/vocab/Agent> . 
      } LIMIT 10
    END
    QUERY_FIND_WORKS = <<-END
      SELECT ?s
      WHERE { 
        ?s <http://www.w3.org/1999/02/22-rdf-syntax-ns#type> <http://bibframe.org/vocab/Work> . 
      } LIMIT 10
    END
    QUERY_FIND_INSTANCES = <<-END
      SELECT ?s
      WHERE { 
        ?s <http://www.w3.org/1999/02/22-rdf-syntax-ns#type> <http://bibframe.org/vocab/Instance> . 
      } LIMIT 10
    END
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
      get_agent_uris.each do |uri|
        agent = @doc_factory.document(:agent, uri)
        if agent
          @ss.add_document(agent.document)
        end
      end
    end

    def get_agent_uris()
      QueryRunner.new(QUERY_FIND_AGENTS).execute(@ts).map { |r| r['s'] }
    end

    def index_instances()
      get_instance_uris.each do |uri|
        instance = @doc_factory.document(:instance, uri)
        if instance
          @ss.add_document(instance.document)
        end
      end
    end

    def get_instance_uris()
      QueryRunner.new(QUERY_FIND_INSTANCES).execute(@ts).map { |r| r['s'] }
    end

    def index_works()
      get_work_uris.each do |uri|
        work = @doc_factory.document(:work, uri)
        if work
          @ss.add_document(work.document)
        end
      end
    end

    def get_work_uris()
      QueryRunner.new(QUERY_FIND_WORKS).execute(@ts).map { |r| r['s'] }
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