=begin
--------------------------------------------------------------------------------

Get all of the URIs for Agents, Instances, and Works.

Build a Solr document for each URI and add it to the Solr index.

--------------------------------------------------------------------------------

Usage: ld4l_build_solr_index [RESTART] <source_site> <report_file> [REPLACE]

--------------------------------------------------------------------------------
=end

module Ld4lIndexing
  class BuildSolrIndex
    USAGE_TEXT = 'Usage is ld4l_build_solr_index [RESTART] <source_site> <report_file> [REPLACE]'
    SOLR_BASE_URL = 'http://localhost:8983/solr/blacklight-core'

    QUERY_FIND_AGENTS = <<-END
      PREFIX foaf: <http://http://xmlns.com/foaf/0.1/>
      SELECT ?uri
      WHERE { 
        ?uri a <http://bibframe.org/vocab/Agent> . 
      }
    END
    QUERY_FIND_WORKS = <<-END
      PREFIX ld4l: <http://ld4l.org/ontology/bib/>
      SELECT ?uri
      WHERE { 
        ?uri <http://www.w3.org/1999/02/22-rdf-syntax-ns#type> <http://bibframe.org/vocab/Work> . 
      }
    END
    QUERY_FIND_INSTANCES = <<-END
      PREFIX ld4l: <http://ld4l.org/ontology/bib/>
      SELECT ?uri
      WHERE { 
        ?uri <http://www.w3.org/1999/02/22-rdf-syntax-ns#type> <http://bibframe.org/vocab/Instance> . 
      }
    END

    TYPES = [
      {:id => :work, :query => QUERY_FIND_WORKS},
      {:id => :instance, :query => QUERY_FIND_INSTANCES},
      {:id => :agent, :query => QUERY_FIND_AGENTS}
    ]

    URI_BATCH_LIMIT = 1000

    def initialize
    end

    def process_arguments(args)
      replace_file = args.delete('REPLACE')
      @restart = args.delete('RESTART')

      raise UserInputError.new(USAGE_TEXT) unless args && args.size == 2

      valid_source_sites = ['Cornell', 'Harvard', 'Stanford']
      raise UserInputError.new("Source site must be one of these: #{valid_source_sites.join(', ')}") unless valid_source_sites.include?(args[0])
      @source_site = args[0]

      raise UserInputError.new("#{args[1]} already exists -- specify REPLACE") if File.exist?(args[1]) unless replace_file
      raise UserInputError.new("Can't create #{args[1]}: no parent directory.") unless Dir.exist?(File.dirname(args[1]))
      @report_file_path = File.expand_path(args[1])
    end

    def prepare_solr()
      @ss = SolrServer.new(SOLR_BASE_URL)
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

    def initialize_bookmark
      @bookmark = Bookmark.new('build_solr_index', @ss, @restart)
    end

    def trap_control_c
      @interrupted = false
      trap("SIGINT") do
        @interrupted = true
      end
    end

    def query_and_index_items()
      uris = UriDiscoverer.new(@bookmark, @ts, @report, TYPES, URI_BATCH_LIMIT)
      uris.each do |type, uri|
        if @interrupted
          process_interruption
          raise UserInputError.new("INTERRUPTED")
        else
          begin
            doc = @doc_factory.document(type, uri)
            @ss.add_document(doc.document) if doc
          rescue
            @report.log_document_error(type, uri, doc, $!)
          end
        end
      end
    end

    def process_interruption
      @bookmark.persist
      @report.summarize(@doc_factory, @bookmark, :interrupted)
    end

    def run()
      begin
        process_arguments(ARGV)
        @report = Report.new('ld4l_build_solr_index', @report_file_path)
        @report.log_header(ARGV)

        prepare_solr
        prepare_triple_store
        prepare_document_factory
        initialize_bookmark
        trap_control_c

        @report.record_counts(Counts.new(@ts))
        query_and_index_items

        @report.summarize(@doc_factory, @bookmark)
        @bookmark.clear
      rescue UserInputError
        puts
        puts "ERROR: #{$!}"
        puts
      ensure
        @report.close if @report
      end
    end
  end
end