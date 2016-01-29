=begin rdoc
--------------------------------------------------------------------------------

Build new Solr index records for a specific set of URIs. If the URI doesn't
represent a Work, Instance, or Agent, it will be noted and ignored.

Specify a directory that holds lists of uris, and a place to put the report.

--------------------------------------------------------------------------------

Usage: ld4l_index_chosen_uris <source_dir> <report_file> [REPLACE]

--------------------------------------------------------------------------------
=end

require_relative 'index_chosen_uris/uri_reader'
require_relative 'index_chosen_uris/chosen_bookmark'

module Ld4lIndexing
  class IndexChosenUris

    USAGE_TEXT = 'Usage is ld4l_index_chosen_uris <source_dir> <report_file> [REPLACE] '
    SOLR_BASE_URL = 'http://localhost:8983/solr/blacklight-core'
    #
    def initialize
    end

    def process_arguments()
      args = Array.new(ARGV)
      replace_file = args.delete('REPLACE')
      raise UserInputError.new(USAGE_TEXT) unless args && args.size == 2

      raise UserInputError.new("#{args[0]} doesn't exist.") unless File.exist?(args[0])
      @source_dir = File.expand_path(args[0])

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

    def do_it
      uris = UriReader.new(@bookmark, @ts, @report, @source_dir)
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

    def initialize_bookmark
      @bookmark = ChosenBookmark.new('index_chosen_uris', @ss)
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
        @report = Report.new('ld4l_index_chosen_uris', @report_file_path)
        @report.log_header(ARGV)

        prepare_solr
        prepare_triple_store
        prepare_document_factory
        initialize_bookmark
        trap_control_c

        do_it

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