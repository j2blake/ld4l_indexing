=begin rdoc
--------------------------------------------------------------------------------

Read the URIs from the selected directory, and return the ones that are of an
acceptable type.

Each line of a file may contain a URI, or it may contain a full N-triple, and
the subject URI will be used.

--------------------------------------------------------------------------------
=end

module Ld4lIndexing
  class IndexChosenUris
    class UriReader
      QUERY_TYPES = <<-END
        SELECT ?type 
        WHERE {
          ?uri a ?type .
        } LIMIT 100
      END

      TYPE_WORK = 'http://bib.ld4l.org/ontology/Work'
      TYPE_INSTANCE = 'http://bib.ld4l.org/ontology/Instance'
      TYPE_PERSON = 'http://xmlns.com/foaf/0.1/Person'
      TYPE_ORGANIZATION = 'http://xmlns.com/foaf/0.1/Organization'
      def initialize(bookmark, ts, report, source_dir)
        @bookmark = bookmark
        @ts = ts
        @report = report
        @source_dir = source_dir

        @uris = []
        get_filenames
      end

      def get_filenames
        @filenames = Dir.entries(@source_dir).reject { |fn| fn.start_with?('.') }
      end

      def each()
        while true
          read_more if @uris.empty?
          return if @uris.empty?

          uri = @uris.shift
          type = find_type(uri)

          if type
            yield type, uri
          else
            @report.logit("couldn't find a type for '#{uri}'")
          end
        end
      end

      def read_more
        return if @filenames.empty?
        @uris = File.readlines(File.join(@source_dir, @filenames.shift)).map {|line| line[/^<?([^>\s]+)>?/, 1] }
      end

      def find_type(uri)
        QueryRunner.new(QUERY_TYPES).bind_uri('uri', uri).execute(@ts).each do |row|
          return :work if TYPE_WORK == row['type']
          return :instance if TYPE_INSTANCE == row['type']
          return :agent if TYPE_PERSON == row['type']
          return :agent if TYPE_ORGANIZATION == row['type']
        end
        return nil
      end
    end
  end
end
