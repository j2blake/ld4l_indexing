=begin

Provide a way to bind variables in a query, and to execute the query.

The triple-store must return a JSON-formatted response to the query. The
'execute' method here will convert that to an array of hashes.

Example:
[
  {'p' => 'http://first/predicate', 'o' => 'http://first/object' },
  {'p' => 'http://second/predicate', 'o' => 'http://second/object' }
]
=end

module Ld4lIndexing
  class QueryRunner
    def initialize(query)
      @initial_query = String.new(query)
      @query = String.new(query)
    end

    def bind_uri(varname, value)
      @query.gsub!(Regexp.new("\\?#{varname}\\b"), "<#{value}>")
      self
    end

    def bind_literal(varname, value)
    end

    def execute(ts)
      result = nil
      ts.sparql_query(@query) do |resp|
        result = parse_response(resp)
      end
      result
    end

    def parse_response(resp)
      JSON.parse(resp.body)['results']['bindings'].map do |row|
        parse_row(row)
      end
    end

    def parse_row(row)
      Hash[row.map { |k, v| [k, v['value']] }]
    end
  end
end
