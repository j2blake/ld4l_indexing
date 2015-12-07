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
      SELECT (count(?uri) as ?count)
      WHERE { 
        ?uri a <http://bibframe.org/vocab/Work> . 
      }
    END
    QUERY_COUNT_INSTANCES = <<-END
      SELECT (count(?uri) as ?count)
      WHERE { 
        ?uri a <http://bibframe.org/vocab/Instance> . 
      }
    END
    QUERY_COUNT_AGENTS = <<-END
      SELECT (count(?uri) as ?count)
      WHERE { 
        ?uri a <http://bibframe.org/vocab/Agent> . 
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