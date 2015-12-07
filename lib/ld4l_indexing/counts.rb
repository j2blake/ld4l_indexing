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
      SELECT (count(?uri) as ?count)
      WHERE { 
        GRAPH ?g {
          ?uri a <http://bibframe.org/vocab/Work> . 
        } 
      }
    END
    QUERY_COUNT_INSTANCES = <<-END
      SELECT (count(?uri) as ?count)
      WHERE { 
        GRAPH ?g {
          ?uri a <http://bibframe.org/vocab/Instance> . 
        } 
      }
    END
    QUERY_COUNT_AGENTS = <<-END
      SELECT (count(?uri) as ?count)
      WHERE {
        GRAPH ?g {
          ?uri a <http://bibframe.org/vocab/Agent> . 
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
