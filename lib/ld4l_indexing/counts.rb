=begin rdoc
--------------------------------------------------------------------------------

Grab some statistics from the triple-store.

--------------------------------------------------------------------------------
=end

module Ld4lIndexing
  class Counts
    QUERY_COUNT_TRIPLES = <<-END
      SELECT (count(?s) as ?count)
      WHERE { 
        ?s ?p ?o .
      }
    END
    QUERY_COUNT_WORKS = <<-END
      PREFIX ld4l: <http://ld4l.org/ontology/bib/>
      SELECT (count(?uri) as ?count)
      WHERE { 
        ?uri a ld4l:Work . 
      }
    END
    QUERY_COUNT_INSTANCES = <<-END
      PREFIX ld4l: <http://ld4l.org/ontology/bib/>
      SELECT (count(?uri) as ?count)
      WHERE { 
        ?uri a ld4l:Instance . 
      }
    END
    QUERY_COUNT_AGENTS = <<-END
      PREFIX foaf: <http://http://xmlns.com/foaf/0.1/>
      SELECT (count(?uri) as ?count)
      WHERE {
        { 
          ?uri a foaf:Person .
        } UNION {
          ?uri a foaf:Organization .
        } 
      }
    END
    def initialize(ts)
      @name = ts.to_s
      @triples = QueryRunner.new(QUERY_COUNT_TRIPLES).execute(ts).map { |row| row['count'] }[0]
      @works = QueryRunner.new(QUERY_COUNT_WORKS).execute(ts).map { |row| row['count'] }[0]
      @instances = QueryRunner.new(QUERY_COUNT_INSTANCES).execute(ts).map { |row| row['count'] }[0]
      @agents = QueryRunner.new(QUERY_COUNT_AGENTS).execute(ts).map { |row| row['count'] }[0]
    end

    def values
      {
        :name => @name,
        :triples => @triples,
        :works => @works,
        :instances => @instances,
        :agents => @agents
      }
    end
  end
end

QUERY_FIND_WORKS = <<-END
  PREFIX ld4l: <http://ld4l.org/ontology/bib/>
  SELECT ?uri
  WHERE { 
    ?uri a ld4l:Work . 
  }
END
QUERY_FIND_INSTANCES = <<-END
  PREFIX ld4l: <http://ld4l.org/ontology/bib/>
  SELECT ?uri
  WHERE { 
    ?uri a ld4l:Instance . 
  }
END
