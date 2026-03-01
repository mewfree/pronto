# frozen_string_literal: true

require "tty-box"
require "tty-cursor"
require "pastel"

module Pronto
  module TUI
    # Renders the "UP NEXT" queue panel with ranked tasks.
    class QueuePanel
      PASTEL = Pastel.new

      def initialize(layout, config)
        @layout = layout
        @config = config
        @cursor = TTY::Cursor
      end

      def render(tasks, focus_index: 0)
        # tasks is the full visible list; we show items after index 0
        queue_tasks = tasks[1..] || []
        max         = @config.ui.queue_max_items
        queue_tasks = queue_tasks.first(max)

        content = build_content(queue_tasks, focus_index)

        box = TTY::Box.frame(
          top:    @layout.queue_top - 1,
          left:   0,
          width:  @layout.width,
          height: @layout.queue_rows,
          title:  { top_left: " UP NEXT " },
          border: :light,
          style:  { border: { fg: :blue } },
        ) { content }

        print box
      end

      private

      def build_content(tasks, _focus_index)
        inner_w = @layout.width - 4
        show_scores = @config.ui.show_scores?
        inner_h = @layout.queue_rows - 2

        if tasks.empty?
          lines = ["  (queue empty)"]
          lines << "" while lines.length < inner_h
          return lines.join("\n")
        end

        lines = tasks.each_with_index.map do |t, i|
          num      = PASTEL.dim("#{i + 1}")
          pri      = t.priority_label ? PASTEL.yellow(t.priority_label) : "    "
          title    = truncate(t.title, inner_w - 30)
          tags     = t.tags_label ? PASTEL.cyan(t.tags_label) : ""
          score    = show_scores ? PASTEL.dim(format("%.2f", t.score)) : ""

          "  #{num}  #{pri} #{title.ljust(inner_w - 28)} #{tags.ljust(12)} #{score}"
        end

        # Pad to fill the panel
        lines << "" while lines.length < inner_h
        lines.first(inner_h).join("\n")
      end

      def truncate(str, max)
        return str if str.nil? || max <= 0 || str.length <= max

        "#{str[0, max - 1]}…"
      end
    end
  end
end
