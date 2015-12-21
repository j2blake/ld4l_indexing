$LOAD_PATH.unshift File.expand_path('../../../triple_store_drivers/lib', __FILE__)
$LOAD_PATH.unshift File.expand_path('../../../triple_store_controller/lib', __FILE__)
require 'triple_store_drivers'
require 'triple_store_controller'

require 'json'
require 'rdf'
require 'rdf/ntriples'

require "ld4l_indexing/build_solr_index"
require "ld4l_indexing/sample_solr_index"
require "ld4l_indexing/bookmark"
require "ld4l_indexing/counts"
require "ld4l_indexing/document_factory"
require "ld4l_indexing/document_stats_accumulator"
require "ld4l_indexing/language_reference"
require "ld4l_indexing/query_runner"
require "ld4l_indexing/report"
require "ld4l_indexing/solr_server"
require "ld4l_indexing/uri_discoverer"
require "ld4l_indexing/version"

require "ld4l_indexing/document_base"
require "ld4l_indexing/agent_document"
require "ld4l_indexing/instance_document"
require "ld4l_indexing/work_document"

module Kernel
  def bogus(message)
    puts(">>>>>>>>>>>>>BOGUS #{message}")
  end
end

module Ld4lIndexing
  # You screwed up the calling sequence.
  class IllegalStateError < StandardError
  end

  # What did you ask for?
  class UserInputError < StandardError
  end
end
