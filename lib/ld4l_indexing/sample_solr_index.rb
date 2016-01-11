=begin rdoc
--------------------------------------------------------------------------------

Select a well-connected sample of the triple-store and build Solr index records
for them.

Specify the number of Works to index, and the routine will also index any related
Indexes and Agents.

Restart will empty out the search index and wipe the bookmark.

--------------------------------------------------------------------------------

Usage: ld4l_sample_solr_index <number_of_works> <report_file> [REPLACE] [RESTART] [cornell|harvard|stanford]

--------------------------------------------------------------------------------
=end

module Ld4lIndexing
  class SampleSolrIndex
    QUERY_FIND_WORKS = <<-END
      PREFIX ld4l: <http://bib.ld4l.org/ontology/>
      SELECT ?uri
      WHERE { 
        GRAPH ?g {
          ?uri a ld4l:Work .
        } 
      }
    END

    TYPES = [
      {:id => :work, :query => QUERY_FIND_WORKS},
    ]

    USAGE_TEXT = 'Usage is ld4l_sample_solr_index <number_of_works> <report_file> [REPLACE] [RESTART] [cornell|harvard|stanford]'
    SOLR_BASE_URL = 'http://localhost:8983/solr/blacklight-core'

    #
    def initialize
    end

    def process_arguments()
      args = Array.new(ARGV)
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

      raise UserInputError.new(USAGE_TEXT) unless args && args.size == 2

      raise UserInputError.new("Number of works must be a positive integer: #{args[0]}") unless args[0].to_i > 0
      @number_of_works = args[0].to_i

      raise UserInputError.new("#{args[1]} already exists -- specify REPLACE") if File.exist?(args[1]) unless replace_file
      raise UserInputError.new("Can't create #{args[1]}: no parent directory.") unless Dir.exist?(File.dirname(args[1]))
      @report_file_path = File.expand_path(args[1])
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

    def index_works()
      bindings = @graph ? {'g' => @graph} : {}
      uris = UriDiscoverer.new(@bookmark, @ts, @report, TYPES, 500, bindings)
      uris.first(@number_of_works).each do |type, uri|
        begin
          if @interrupted
            process_interruption
            raise UserInputError.new("INTERRUPTED")
          else
            begin
              doc = @doc_factory.document(type, uri)
              if doc
                @ss.add_document(doc.document)
                index_instances(doc.values["instances"])
                index_agents(doc.values['creators'].map {|c| c.uri})
                index_agents(doc.values['contributors'].map {|c| c.uri})
              end
            rescue
              @report.log_document_error(:work, uri, doc, $!)
            end
          end
        end
      end
    end

    def index_instances(instances)
      instances.each do |instance|
        uri = instance[:uri]
        begin
          doc = @doc_factory.document(:instance, uri)
          if doc
            @ss.add_document(doc.document)
          end
        rescue
          @report.log_document_error(:instance, uri, doc, $!)
        end
      end
    end

    def index_agents(uris)
      uris.each do |uri|
        begin
          doc = @doc_factory.document(:agent, uri)
          if doc
            @ss.add_document(doc.document)
          end
        rescue
          @report.log_document_error(:agent, uri, doc, $!)
        end
      end
    end

    def initialize_bookmark
      @bookmark = Bookmark.new('sample_solr_index', @ss, @restart)
    end

    def trap_control_c
      @interrupted = false
      trap("SIGINT") do
        @interrupted = true
      end
    end

    def process_interruption
      @ss.commit
      @bookmark.persist
      @report.summarize(@doc_factory, @bookmark, :interrupted)
    end

    def run()
      begin
        process_arguments
        @report = Report.new('ld4l_sample_solr_index', @report_file_path)
        @report.log_header(ARGV)

        prepare_solr
        prepare_triple_store
        prepare_document_factory
        initialize_bookmark
        trap_control_c

        @report.record_counts(Counts.new(@ts, @graph))
        index_works
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