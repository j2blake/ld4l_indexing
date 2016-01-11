module Ld4lIndexing
  class Report
    def initialize(main_routine, path)
      @file = File.open(path, 'w')
      @main_routine = main_routine
    end

    def log_header(args)
      logit "#{@main_routine} #{args.join(' ')}"
    end

    def record_counts(counts)
      logit "%{name}: %{triples} triples, %{works} works, %{instances} instances, %{agents} agents." % counts.values
    end

    def log_document_error(type, uri, doc, error)
      backtrace = error.backtrace.join("\n   ")
      if error.respond_to?(:cause)
        logit "%s %s\n%s\n%s\n   %s" % [type, error, error.cause, doc_error_display(doc), backtrace]
      else
        logit "%s %s\n%s\n   %s" % [type, error, doc_error_display(doc), backtrace]
      end
    end

    def doc_error_display(doc)
      if doc
        if doc.respond_to?(:document) && doc.document
          "Solr document: " + doc.document.inspect
        else
          "uri= %s, properties= %s, values= %s" % [doc.uri, doc.properties.inspect, doc.values.inspect]
        end
      else
        ""
      end
    end

    def progress(type, offset, found)
      logit "Progress: %s, offset %d, found %d" % [type, offset, found]
    end

    def summarize(doc_factory, bookmark, status=:complete)
      if status != :complete
        logit ">>>>>>>INTERRUPTED<<<<<<<\n\n"
      else
      end
      logit "%s\n%s\n%s" % [doc_factory.work_stats,
        doc_factory.instance_stats,
        doc_factory.agent_stats
      ]
    end

    def logit(message)
      m = "#{Time.new.strftime('%Y-%m-%d %H:%M:%S')} #{message}"
      puts(m)
      $stdout.flush
      @file.puts(m)
      @file.flush
    end

    def close()
      @file.close if @file
    end
  end
end