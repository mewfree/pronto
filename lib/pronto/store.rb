# frozen_string_literal: true

module Pronto
  # Aggregates tasks from all configured .org files and returns them ranked.
  class Store
    attr_reader :tasks, :skip_cooldown_minutes

    def initialize(config)
      @config                = config
      @scorer                = Scorer.new(config)
      @skip_cooldown_minutes = config.scoring.skip_cooldown_minutes
      @skip_registry         = {}  # node_id => skipped_at Time
      @tasks                 = []
    end

    def reload!
      parser = Org::Parser.new(
        active_keywords: @config.active_keywords,
        done_keywords:   @config.done_keywords,
      )

      nodes = []
      @config.files.each do |path|
        next unless File.exist?(path)

        nodes.concat(parser.parse_file(path))
      rescue => e
        warn "pronto: error reading #{path}: #{e.message}"
      end

      active_nodes = nodes.select(&:active?)

      @tasks = active_nodes.map do |node|
        task = Task.new(node: node, score: @scorer.score(node))
        # Restore skip state if present
        if (skip_time = @skip_registry[node_id(node)])
          task.skipped_at = skip_time
        end
        task
      end

      sort!
      @tasks
    end

    # Returns tasks visible in the queue (not currently skipped, or cooldown expired)
    def visible_tasks
      now = Time.now
      @tasks.reject do |t|
        t.skipped? && now < t.skipped_at
      end
    end

    def skip!(task)
      task.skip!(@skip_cooldown_minutes)
      @skip_registry[node_id(task.node)] = task.skipped_at
      sort!
    end

    def total_count
      @tasks.size
    end

    def done_count
      # Count tasks that were done this session (tracked separately by CLI/TUI)
      @done_count ||= 0
    end

    def increment_done!
      @done_count = done_count + 1
    end

    private

    def sort!
      @tasks.sort_by! { |t| -t.score }
    end

    def node_id(node)
      "#{node.file}:#{node.line_start}"
    end
  end
end
