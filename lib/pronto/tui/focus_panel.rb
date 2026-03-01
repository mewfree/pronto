# frozen_string_literal: true

require "tty-box"
require "tty-cursor"
require "pastel"

module Pronto
  module TUI
    # Renders the "FOCUS NOW" panel showing the current top task.
    class FocusPanel
      PASTEL = Pastel.new

      def initialize(layout, config)
        @layout = layout
        @config = config
        @cursor = TTY::Cursor
      end

      def render(task)
        print @cursor.move_to(0, @layout.focus_top - 1)

        if task.nil?
          box = TTY::Box.frame(
            top:    @layout.focus_top - 1,
            left:   0,
            width:  @layout.width,
            height: @layout.focus_rows,
            title:  { top_left: " FOCUS NOW " },
            border: :thick,
          ) { "  No active tasks. Press [a] to add one." }
          print box
          return
        end

        content = build_content(task)

        box = TTY::Box.frame(
          top:    @layout.focus_top - 1,
          left:   0,
          width:  @layout.width,
          height: @layout.focus_rows,
          title:  { top_left: " FOCUS NOW ", top_right: score_badge(task) },
          border: :thick,
          style:  { fg: :white, border: { fg: :cyan } },
        ) { content }

        print box
      end

      private

      def score_badge(task)
        score_str = @config.ui.show_scores? ? " score: #{format('%.2f', task.score)} " : ""
        pri_str   = task.priority ? " [##{task.priority}] " : ""
        "#{score_str}#{pri_str}"
      end

      def build_content(task)
        inner_w = @layout.width - 4  # subtract box borders + padding
        lines = []

        # Title line
        title = task.priority_label ? "#{task.priority_label} #{task.title}" : task.title
        lines << PASTEL.bold(truncate(title, inner_w))
        lines << ""

        # Planning line
        planning_parts = []
        planning_parts << "DEADLINE: #{format_ts(task.deadline)}"   if task.deadline
        planning_parts << "SCHEDULED: #{format_ts(task.scheduled)}" if task.scheduled
        lines << planning_parts.join("   ") unless planning_parts.empty?

        # Tags + effort
        meta_parts = []
        meta_parts << "Tags: #{task.tags_label}" if task.tags_label
        meta_parts << "Effort: #{task.effort_label}" if task.effort_label
        lines << meta_parts.join("   ") unless meta_parts.empty?

        # Fill remaining height with blank lines
        inner_h = @layout.focus_rows - 2  # subtract top/bottom borders
        while lines.length < inner_h
          lines << ""
        end

        lines.map { |l| "  #{truncate(l, inner_w)}" }.join("\n")
      end

      def format_ts(ts)
        return "" unless ts

        ts.date.strftime("%a %b %-d")
      end

      def truncate(str, max)
        return str if str.length <= max

        "#{str[0, max - 1]}…"
      end
    end
  end
end
