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
        GRAPH ?g {
          ?s ?p ?o .
        }
      }
    END
    QUERY_COUNT_WORKS = <<-END
      PREFIX ld4l: <http://bib.ld4l.org/ontology/>
      SELECT (count(?uri) as ?count)
      WHERE { 
        GRAPH ?g {
          ?uri a ld4l:Work .
        } 
      }
    END
    QUERY_COUNT_INSTANCES = <<-END
      PREFIX ld4l: <http://bib.ld4l.org/ontology/>
      SELECT (count(?uri) as ?count)
      WHERE { 
        GRAPH ?g {
          ?uri a ld4l:Instance .
        } 
      }
    END
    QUERY_COUNT_AGENTS = <<-END
      PREFIX foaf: <http://xmlns.com/foaf/0.1/>
      SELECT (count(?uri) as ?count)
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
    def initialize(ts, graph)
      @ts = ts
      @name = ts.to_s
      @graph = graph
      @triples = run_query(QUERY_COUNT_TRIPLES)
      @works = run_query(QUERY_COUNT_WORKS)
      @instances = run_query(QUERY_COUNT_INSTANCES)
      @agents = run_query(QUERY_COUNT_AGENTS)
    end

    def run_query(q)
      query = QueryRunner.new(q)
      query.bind_uri('g', @graph) if @graph
      query.execute(@ts).map { |row| row['count'] }[0]
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
