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
      doc_string = doc ? doc.document : "NO DOCUMENT FOR #{uri}"
      backtrace = error.backtrace.join("\n   ")
      logit "%s %s\n%s\n   %s" % [type, doc_string, error, backtrace]
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
      puts m
      @file.puts(m)
    end

    def close()
      @file.close if @file
    end
  end
end