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
    include Enumerable
    def initialize(bookmark, ts, report, types, limit)
      @bookmark = bookmark
      @ts = ts
      @report = report
      @types = types
      @limit = limit
      @uris = []
    end

    def each()
      while true
        replenish_buffer if @uris.empty?
        advance_to_next_type if @uris.empty?
        return if @uris.empty?

        type_id = @types[@bookmark.type_index][:id]
        yield type_id, @uris.shift
        @bookmark.increment
      end
    end

    def advance_to_next_type()
      if @bookmark.type_index < @types.size - 1
        @bookmark.next_type
        replenish_buffer
      end
    end

    def replenish_buffer()
      @uris = find_uris("%s OFFSET %d LIMIT %d" % [
        @types[@bookmark.type_index][:query],
        @bookmark.offset,
        @limit
      ])
      @report.progress(@types[@bookmark.type_index][:id], @bookmark.offset, @uris.size) unless @uris.empty?
    end

    def find_uris(query)
      QueryRunner.new(query).execute(@ts).map { |r| r['uri'] }
    end

  end
end
