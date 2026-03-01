# frozen_string_literal: true

require "tty-box"
require "pastel"

module Pronto
  module TUI
    # Renders the bottom status/hints bar.
    class StatusBar
      PASTEL = Pastel.new
      HINTS  = "[d]one  [s]kip  [a]dd  [l]ist  [r]efresh  [q]uit"

      def initialize(layout)
        @layout = layout
      end

      def render(store)
        visible  = store.visible_tasks.size
        total    = store.total_count
        done     = store.done_count
        stats    = "done:#{done}/#{total}  visible:#{visible}"

        hint_str  = PASTEL.dim(HINTS)
        stats_str = PASTEL.green(stats)

        # Pad between hints and stats
        inner_w   = @layout.width - 4
        hint_plain = HINTS
        pad_width  = [inner_w - hint_plain.length - stats.length, 1].max
        content    = "#{hint_str}#{' ' * pad_width}#{stats_str}"

        box = TTY::Box.frame(
          top:    @layout.status_top - 1,
          left:   0,
          width:  @layout.width,
          height: @layout.status_rows,
          border: :light,
          style:  { border: { fg: :white } },
        ) { "  #{content}" }

        print box
      end
    end
  end
end
