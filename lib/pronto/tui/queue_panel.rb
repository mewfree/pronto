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

      def render(tasks, focus_index: 0, scroll: 0)
        # tasks is the full visible list; we show items after index 0
        queue_tasks = tasks[1..] || []

        content = build_content(queue_tasks, focus_index, scroll)

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

      ANSI_RE = /\e\[[0-9;]*m/
      SCORE_W = 5   # " 0.00"
      TAGS_W  = 12
      PRI_W   = 4   # "[#A]"
      NUM_W   = 2
      # fixed overhead: "  " + num + "  " + pri + " " + " " + tags + " " + score = 2+2+2+4+1+1+12+1+5 = 30
      FIXED_W = 2 + NUM_W + 2 + PRI_W + 1 + 1 + TAGS_W + 1 + SCORE_W

      def build_content(tasks, focus_index, scroll)
        inner_w = @layout.width - 4
        show_scores = @config.ui.show_scores?
        inner_h = @layout.queue_rows - 2
        title_w = [inner_w - FIXED_W, 4].max
        # focus_index is the global index; queue starts at tasks[1], so
        # the highlighted row in the queue is at queue index (focus_index - 1)
        highlighted = focus_index - 1

        if tasks.empty?
          lines = [ansi_ljust("  (queue empty)", inner_w)]
          lines << " " * inner_w while lines.length < inner_h
          return lines.join("\n")
        end

        visible = tasks[scroll, inner_h] || []

        lines = visible.each_with_index.map do |t, i|
          qi         = i + scroll  # index in full queue_tasks
          num_str    = format("%#{NUM_W}d", qi + 1)
          num        = qi == highlighted ? PASTEL.bold(num_str) : PASTEL.dim(num_str)
          pri_str    = t.priority_label ? t.priority_label.ljust(PRI_W) : " " * PRI_W
          pri        = qi == highlighted ? PASTEL.bold(pri_str) : PASTEL.yellow(pri_str)
          title_str  = truncate(t.title, title_w).ljust(title_w)
          title      = qi == highlighted ? PASTEL.bold(title_str) : title_str
          tags_plain = truncate(t.tags_label || "", TAGS_W)
          tags       = tags_plain.empty? ? " " * TAGS_W : PASTEL.cyan(tags_plain) + " " * (TAGS_W - tags_plain.length)
          score      = show_scores ? PASTEL.dim(format("%#{SCORE_W}.2f", t.score)) : " " * SCORE_W

          ansi_ljust("  #{num}  #{pri} #{title} #{tags} #{score}", inner_w)
        end

        # Pad to fill the panel
        lines << " " * inner_w while lines.length < inner_h
        lines.join("\n")
      end

      def ansi_ljust(str, width)
        visible = str.gsub(ANSI_RE, "").length
        padding = [width - visible, 0].max
        str + " " * padding
      end

      def truncate(str, max)
        return str if str.nil? || max <= 0 || str.length <= max

        "#{str[0, max - 1]}…"
      end
    end
  end
end
