module Ld4lIndexing
  class Counter
    attr_reader :docs_count
    attr_reader :occurences
    def initialize()
      @docs_count = 0
      @occurences = 0
    end

    def add_occurences(count)
      @docs_count += 1
      @occurences += count
    end
  end

  class CountsMap < Hash
    def add_occurences(key, count)
      counter = fetch(key, Counter.new)
      counter.add_occurences(count)
      store(key, counter)
    end
  end

  class DocumentStatsAccumulator
    attr_reader :docs_count
    def initialize(label)
      @label = label
      @docs_count = 0
      @predicate_counts = CountsMap.new
      @value_counts = CountsMap.new
      @warning_counts = CountsMap.new
    end

    def record(doc)
      record_document(doc)
      record_predicates(doc)
      record_values(doc)
    end

    def record_document(doc)
      @docs_count += 1
    end

    # properties is an array of maps
    def record_predicates(doc)
      counts_map = Hash.new {0}
      doc.properties.each do |prop|
        counts_map[prop['p']] += 1
      end
      counts_map.each do |k, v|
        @predicate_counts.add_occurences(k, v)
      end
    end

    # values is a map of arrays
    def record_values(doc)
      doc.values.each do |k, v|
        @value_counts.add_occurences(k, v.size) unless v.empty?
      end
    end
    
    def warning(str)
      @warning_counts.add_occurences(str, 1)
    end

    def to_s()
      "\n%s: %s\nPREDICATES:\n%s\nVALUES:\n%s\nWARNINGS:\n%s" % [@label, @docs_count, format_predicate_counts, format_value_counts, format_warnings]
    end

    def format_predicate_counts
      header = "   count    #docs   property"
      @predicate_counts.to_a.sort {|a, b| a[0] <=> b[0]}.inject([header]) do |lines, item|
        lines << "%8d  %8d   %s" % [item[1].occurences, item[1].docs_count, item[0]]
      end.join("\n")
    end

    def format_value_counts
      header = "   count    #docs   value"
      @value_counts.to_a.sort {|a, b| a[0] <=> b[0]}.inject([header]) do |lines, item|
        lines << "%8d  %8d   %s" % [item[1].occurences, item[1].docs_count, item[0]]
      end.join("\n")
    end
    
    def format_warnings
      header = "   count   message"
      @warning_counts.to_a.sort {|a, b| a[0] <=> b[0]}.inject([header]) do |lines, item|
        lines << "%8d   %s" % [item[1].occurences, item[0]]
      end.join("\n")
    end
  end
end
