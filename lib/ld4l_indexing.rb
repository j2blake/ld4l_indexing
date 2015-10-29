$LOAD_PATH.unshift File.expand_path('../../../triple_store_drivers/lib')
require 'triple_store_drivers'

$LOAD_PATH.unshift File.expand_path('../../../triple_store_controller/lib')
require 'triple_store_controller'

require "ld4l_indexing/build_solr_index"
require "ld4l_indexing/document_factory"
require "ld4l_indexing/document_stats_accumulator"
require "ld4l_indexing/query_runner"
require "ld4l_indexing/solr_server"
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
