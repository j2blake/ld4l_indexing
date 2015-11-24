=begin rdoc
--------------------------------------------------------------------------------

Maintain a bookmark as a Solr document.

--------------------------------------------------------------------------------
=end

module Ld4lIndexing
  class Bookmark
    FILE_NAME = "bookmark_linked_data_creator.json"

    attr_reader :document_id
    attr_reader :type_index
    attr_reader :offset
    attr_reader :count
    def initialize(key, solr, restart)
      @document_id = 'bookmark_' + key
      @solr = solr

      if restart
        reset
      else
        load
      end

      @start_offset = @offset
    end

    def load()
      response = @solr.get_document(@document_id)
      begin
        count = response['response']['numFound']
        if count == 0
          reset
        else
          doc = response['response']['docs'][0]
          @offset = doc['offset_i']
          @type_index = doc['type_index_i']
        end
      rescue
        bogus "Threw an exception while loading the bookmark: #{$!}"
        raise $!
      end
    end

    def reset()
      @offset = 0
      @type_index = 0
      persist
    end

    def persist()
      begin
        @solr.add_document({:id => @document_id, :offset_i => @offset, :type_index_i => @type_index})
      rescue
        bogus "Threw an exception while storing the bookmark: #{$!}"
        raise $!
      end
    end

    def next_type()
      @type_index += 1
      @offset = 0
      persist
    end

    def increment()
      @offset += 1
    end

    def clear()
      @solr.delete_by_id(@document_id)
    end
  end
end
