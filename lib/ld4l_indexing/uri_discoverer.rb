=begin
--------------------------------------------------------------------------------

Repeatedly get bunches of URIs for Agents, Instances, and Works. Dispense them
one at a time.

The query should return the uris in ?uri, and should not contain an OFFSET or
LIMIT, since they will be added here.

--------------------------------------------------------------------------------
=end

module Ld4lIndexing
  class UriDiscoverer
    def initialize(ts, query, limit)
      @ts = ts
      @query = query
      @limit = limit
      @offset = 0
      @uris = []
    end

    def each()
      while true
        replenish_buffer if @uris.empty?
        return if @uris.empty?
        yield @uris.shift
      end
    end

    def replenish_buffer()
      @uris = find_uris("%s OFFSET %d LIMIT %d" % [@query, @offset, @limit])
      @offset += @limit
    end

    def find_uris(query)
      QueryRunner.new(query).execute(@ts).map { |r| r['uri'] }
    end

  end
end