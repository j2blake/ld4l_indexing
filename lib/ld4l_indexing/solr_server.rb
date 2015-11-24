require 'rubygems'
require 'rsolr'

module Ld4lIndexing
  class SolrServer
    def initialize(solr_url)
      @solr_url = solr_url
      @solr = RSolr.connect(:url => solr_url)
    end

    def running?
      begin
        result = @solr.select(:params => {:q => "bogus"})
        true
      rescue
        false
      end
    end

    #  def clear()
    #    @solr.delete_by_query("*:*")
    #  end

    def add_document(doc)
      @solr.add doc
      @solr.commit
    end
    
    def get_document(id)
      @solr.get('select', :params => { :qt => 'document', :id => id })
    end
    
    #    def query(q)
    #      @solr.get('select', :params => { :q => q })
    #    end

    def commit()
      @solr.commit
    end
    
    def delete_by_id(id)
      @solr.delete_by_id([id])
      @solr.commit
    end

    def to_s
      "Solr server at #{@solr_url}"
    end
  end
end