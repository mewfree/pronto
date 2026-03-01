# frozen_string_literal: true

require "tty-screen"

module Pronto
  module TUI
    # Computes screen region sizes based on terminal dimensions.
    Layout = Struct.new(:width, :height, :focus_rows, :queue_rows, :status_rows) do
      STATUS_ROWS = 3  # border + content + border

      def self.compute(focus_pct: 0.40)
        w = TTY::Screen.width
        h = TTY::Screen.height

        status = STATUS_ROWS
        # Focus panel: percentage of total, including its borders
        focus_h = [(h * focus_pct).round, 5].max
        # Queue panel: rest minus status bar
        queue_h = [h - focus_h - status, 4].max

        new(w, h, focus_h, queue_h, status)
      end

      def focus_top  = 1
      def queue_top  = focus_rows + 1
      def status_top = focus_rows + queue_rows + 1
    end
  end
end
