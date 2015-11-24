=begin rdoc
--------------------------------------------------------------------------------

Select a well-connected sample of the triple-store and build Solr index records
for them.

Specify the number of Works to index, and the routine will also index any related
Indexes and Agents.

--------------------------------------------------------------------------------

Usage: ld4l_sample_solr_index <source_site> <number_of_works> <report_file> [REPLACE]

--------------------------------------------------------------------------------
=end

module Ld4lIndexing
  class SampleSolrIndex
    QUERY_FIND_WORKS = <<-END
      PREFIX ld4l: <http://ld4l.org/ontology/bib/>
      SELECT ?uri
      WHERE { 
        ?uri a ld4l:Work . 
      }
    END

    TYPES = [
      {:id => :work, :query => QUERY_FIND_WORKS},
    ]

    USAGE_TEXT = 'Usage is ld4l_sample_solr_index <source_site> <number_of_works> <report_file> [REPLACE]'
    SOLR_BASE_URL = 'http://localhost:8983/solr/blacklight-core'

    #
    def initialize
    end

    def process_arguments(args)
      replace_file = args.delete('REPLACE')

      raise UserInputError.new(USAGE_TEXT) unless args && args.size == 3

      sites = ['Cornell', 'Harvard', 'Stanford']
      raise UserInputError.new("Source site must be one of these: #{sites.join(', ')}") unless sites.include?(args[0])
      @source_site = args[0]

      raise UserInputError.new("Number of works must be a positive integer: #{args[1]}") unless args[1].to_i > 0
      @number_of_works = args[1].to_i

      raise UserInputError.new("#{args[2]} already exists -- specify REPLACE") if File.exist?(args[2]) unless replace_file
      raise UserInputError.new("Can't create #{args[2]}: no parent directory.") unless Dir.exist?(File.dirname(args[2]))
      @report_file_path = File.expand_path(args[2])
    end

    def log_header(args)
      logit "ld4l_sample_solr_index #{args.join(' ')}"
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

    def index_works()
      uris = UriDiscoverer.new(@bookmark, @ts, @report, TYPES, @number_of_works)
      uris.each do |type, uri|
        begin
          if @interrupted
            process_interruption
            raise UserInputError.new("INTERRUPTED")
          else
            begin
              doc = @doc_factory.document(type, uri)
              if doc
                @ss.add_document(doc.document)
                index_instances(doc.values["instance_uris"])
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

    def index_instances(uris)
      uris.each do |uri|
        begin
          doc = @doc_factory.document(:instance, uri)
          if doc
            @ss.add_document(doc.document)
          end
        rescue
          log_document_error(:instance, uri, doc, $!)
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
          log_document_error(:agent, uri, doc, $!)
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
      @bookmark.persist
      @report.summarize(@doc_factory, @bookmark, :interrupted)
    end

    def run()
      begin
        process_arguments(ARGV)
        @report = Report.new('ld4l_sample_solr_index', @report_file_path)
        @report.log_header(ARGV)

        prepare_solr
        prepare_triple_store
        prepare_document_factory
        initialize_bookmark
        trap_control_c

        index_works
        @report.summarize(@doc_factory, @bookmark)
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