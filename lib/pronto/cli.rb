# frozen_string_literal: true

require "thor"
require "date"

module Pronto
  class CLI < Thor
    package_name "pronto"

    def self.exit_on_failure?
      true
    end

    desc "ui", "Open the interactive TUI (default)"
    def ui
      require_relative "tui/app"
      store = build_store
      store.reload!
      TUI::App.new(store, config).run
    end

    desc "next", "Print the top-ranked task"
    def next
      store = build_store
      store.reload!
      task = store.visible_tasks.first
      if task
        parts = [task.keyword, task.priority_label, task.title, task.tags_label].compact
        puts parts.join(" ")
      else
        puts "No active tasks found."
      end
    end

    desc "list", "Show ranked task list"
    option :limit, type: :numeric, aliases: "-n", default: 20, desc: "Max tasks to show"
    option :tag,   type: :string,  aliases: "-t",              desc: "Filter by tag"
    def list
      store = build_store
      store.reload!
      tasks = store.visible_tasks
      tasks = tasks.select { |t| t.tags.include?(options[:tag]) } if options[:tag]
      tasks = tasks.first(options[:limit])

      if tasks.empty?
        puts "No active tasks found."
        return
      end

      require "tty-table"
      rows = tasks.each_with_index.map do |t, i|
        score_str = config.ui.show_scores? ? format("%.2f", t.score) : ""
        [
          (i + 1).to_s,
          t.priority_label || "    ",
          t.title,
          t.tags_label || "",
          score_str,
        ]
      end

      table = TTY::Table.new(
        header: ["#", "Pri", "Title", "Tags", "Score"],
        rows: rows,
      )
      puts table.render(:unicode, padding: [0, 1])
    end

    desc "done QUERY", "Mark a task done by fuzzy title match"
    def done(query)
      store = build_store
      store.reload!
      task = fuzzy_find(store.visible_tasks, query)
      if task.nil?
        warn "No task matching: #{query}"
        exit 1
      end

      writer = Org::Writer.new
      writer.mark_done(task.node, insert_closed: config.insert_closed_timestamp?)
      puts "Marked done: #{task.title}"
    end

    desc "add TITLE", "Add a new task"
    option :priority,  type: :string,  aliases: "-p", desc: "Priority: A, B, or C"
    option :scheduled, type: :string,  aliases: "-s", desc: "Scheduled date (YYYY-MM-DD)"
    option :tag,       type: :array,   aliases: "-t", desc: "Tags (repeatable)"
    option :file,      type: :string,  aliases: "-f", desc: "Target .org file"
    def add(title)
      file = options[:file] ? File.expand_path(options[:file]) : config.default_file

      # Ensure the file exists
      FileUtils.mkdir_p(File.dirname(file))
      FileUtils.touch(file) unless File.exist?(file)

      priority  = options[:priority]&.upcase
      tags      = Array(options[:tag])
      scheduled = options[:scheduled] ? Date.parse(options[:scheduled]) : nil

      props = {}
      props["CREATED"] = "[#{Date.today.strftime('%Y-%m-%d %a')}]"

      writer = Org::Writer.new
      writer.append_task(
        file:      file,
        title:     title,
        keyword:   "TODO",
        priority:  priority,
        scheduled: scheduled,
        tags:      tags,
        properties: props,
      )
      puts "Added: #{title} → #{file}"
    end

    # Default command: open TUI
    default_task :ui

    private

    def config
      @config ||= Config.new
    end

    def build_store
      Store.new(config)
    end

    def fuzzy_find(tasks, query)
      q = query.downcase
      # Exact substring first, then any-word match
      tasks.find { |t| t.title.downcase.include?(q) } ||
        tasks.find { |t| q.split.all? { |w| t.title.downcase.include?(w) } }
    end
  end
end
