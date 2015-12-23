=begin
--------------------------------------------------------------------------------

Get all of the URIs for Agents, Instances, and Works.

Build a Solr document for each URI and add it to the Solr index.

--------------------------------------------------------------------------------

Usage: ld4l_build_solr_index [RESTART] <report_file> [REPLACE] [cornell|harvard|stanford]

--------------------------------------------------------------------------------
=end

module Ld4lIndexing
  class BuildSolrIndex
    USAGE_TEXT = 'Usage is ld4l_build_solr_index [RESTART] <report_file> [REPLACE] [cornell|harvard|stanford]'
    SOLR_BASE_URL = 'http://localhost:8983/solr/blacklight-core'

    QUERY_FIND_AGENTS = <<-END
      PREFIX foaf: <http://xmlns.com/foaf/0.1/>
      SELECT ?uri
      WHERE {
        GRAPH ?g {
          { 
            ?uri a foaf:Person .
          } UNION {
            ?uri a foaf:Organization .
          } 
        }
      }
    END
    QUERY_FIND_WORKS = <<-END
      PREFIX ld4l: <http://ld4l.org/ontology/bib/>
      SELECT ?uri
      WHERE {
        GRAPH ?g { 
          ?uri a ld4l:Work .
        } 
      }
    END
    QUERY_FIND_INSTANCES = <<-END
      PREFIX ld4l: <http://ld4l.org/ontology/bib/>
      SELECT ?uri
      WHERE {
        GRAPH ?g { 
          ?uri a ld4l:Instance .
        } 
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
      @restart_run = args.delete('RESTART')

      sites = [args.delete('cornell'), args.delete('harvard'), args.delete('stanford')].compact
      case sites.size
      when 0
        @graph = nil
      when 1
        @graph = DocumentFactory::GRAPH_NAMES[sites[0]]
      else
        raise UserInputError.new("you may not specify more than one site name: #{sites.inspect}")
      end

      raise UserInputError.new(USAGE_TEXT) unless args && args.size == 1

      raise UserInputError.new("#{args[0]} already exists -- specify REPLACE") if File.exist?(args[0]) unless replace_file
      raise UserInputError.new("Can't create #{args[0]}: no parent directory.") unless Dir.exist?(File.dirname(args[0]))
      @report_file_path = File.expand_path(args[0])
    end

    def prepare_solr()
      @ss = SolrServer.new(SOLR_BASE_URL)
      raise UserInputError.new("#{@ss} is not running") unless @ss.running?

      if @restart_run
        if confirm_intentions?
          @ss.clear
        else
          raise UserInputError.new("OK. Skip it.")
        end
      end
    end

    def confirm_intentions?
      puts "Solr contains #{@ss.num_docs} documemts."
      puts "Delete them? (yes/no) ?"
      'yes' == STDIN.gets.chomp
    end

    def prepare_triple_store()
      selected = TripleStoreController::Selector.selected
      raise UserInputError.new("No triple store selected.") unless selected

      TripleStoreDrivers.select(selected)
      @ts = TripleStoreDrivers.selected

      raise UserInputError.new("#{@ts} is not running") unless @ts.running?
    end

    def prepare_document_factory
      @doc_factory = DocumentFactory.new(@ts)
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
      bindings = @graph ? {'g' => @graph} : {}
      uris = UriDiscoverer.new(@bookmark, @ts, @report, TYPES, URI_BATCH_LIMIT, bindings)
      uris.each do |type, uri|
        if @interrupted
          process_interruption
          raise UserInputError.new("INTERRUPTED")
        else
          begin
            doc = @doc_factory.document(type, uri)
            @ss.add_document(doc.document) if doc
          rescue DocumentError
            @report.log_document_error(type, uri, $!.doc, $!.cause)
          rescue
            @report.log_document_error(type, uri, doc, $!)
          end
        end
      end
    end

    def process_interruption
      @ss.commit
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

        @report.record_counts(Counts.new(@ts, @graph))
        query_and_index_items

        @report.summarize(@doc_factory, @bookmark)
        @ss.commit
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