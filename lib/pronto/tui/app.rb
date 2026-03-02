# frozen_string_literal: true

require "io/console"
require "tty-cursor"
require "tty-screen"
require_relative "layout"
require_relative "focus_panel"
require_relative "queue_panel"
require_relative "status_bar"
require_relative "input"

module Pronto
  module TUI
    # Main TUI event loop. Manages terminal setup/teardown and dispatches key events.
    class App
      SCROLL_MARGIN = 2

      def initialize(store, config)
        @store        = store
        @config       = config
        @cursor       = TTY::Cursor
        @focus_index  = 0
        @queue_scroll = 0
        @running      = false
      end

      def run
        setup_terminal
        setup_signals

        @running = true
        render

        Input.with_raw_input do
          while @running
            key = Input.read_key(timeout: 2.0)
            next if key == :timeout

            handle_key(key)
          end
        end
      ensure
        teardown_terminal
      end

      private

      def setup_terminal
        print @cursor.hide
        print @cursor.clear_screen
        print @cursor.move_to(0, 0)
        $stdout.flush
      end

      def teardown_terminal
        print @cursor.show
        print @cursor.move_to(0, layout.height)
        print "\n"
        $stdout.flush
      end

      def setup_signals
        Signal.trap("WINCH") do
          @layout = nil  # force recompute
          render
        end
        Signal.trap("INT") do
          @running = false
        end
      end

      def layout
        @layout ||= Layout.compute(focus_pct: @config.ui.focus_panel_height_pct)
      end

      def focus_panel
        @focus_panel ||= FocusPanel.new(layout, @config)
      end

      def queue_panel
        @queue_panel ||= QueuePanel.new(layout, @config)
      end

      def status_bar
        @status_bar ||= StatusBar.new(layout)
      end

      def invalidate_panels!
        @focus_panel = nil
        @queue_panel = nil
        @status_bar  = nil
      end

      def tasks
        @store.visible_tasks
      end

      def current_task
        tasks[@focus_index]
      end

      def render
        invalidate_panels!
        print @cursor.move_to(0, 0)
        focus_panel.render(current_task)
        queue_panel.render(tasks, focus_index: @focus_index, scroll: @queue_scroll)
        status_bar.render(@store)
        $stdout.flush
      end

      def handle_key(key)
        case key
        when :quit
          @running = false
        when :done
          handle_done
        when :skip
          handle_skip
        when :add
          handle_add
        when :refresh
          handle_refresh
        when :down, :right
          advance_focus(1)
        when :up, :left
          advance_focus(-1)
        when :list
          # No-op in TUI (list is a CLI-only command)
          nil
        end
      end

      def handle_done
        task = current_task
        return unless task

        writer = Org::Writer.new
        begin
          writer.mark_done(task.node, insert_closed: @config.insert_closed_timestamp?)
          @store.increment_done!
        rescue => e
          show_error("Error marking done: #{e.message}")
          return
        end

        # Reload and reset focus
        @store.reload!
        @focus_index  = 0
        @queue_scroll = 0
        render
      end

      def handle_skip
        task = current_task
        return unless task

        @store.skip!(task)
        @focus_index  = [@focus_index, tasks.size - 1].min
        @focus_index  = 0 if @focus_index < 0
        @queue_scroll = 0
        render
      end

      def handle_add
        # Temporarily exit raw mode to accept text input
        teardown_terminal

        print @cursor.show
        print "\nAdd task title: "
        $stdout.flush

        title = nil
        begin
          # Restore cooked mode for line input
          $stdin.cooked { title = $stdin.gets&.chomp }
        rescue Interrupt
          title = nil
        end

        if title && !title.empty?
          writer = Org::Writer.new
          props  = { "CREATED" => "[#{Date.today.strftime('%Y-%m-%d %a')}]" }
          begin
            writer.append_task(
              file:       @config.default_file,
              title:      title,
              keyword:    "TODO",
              properties: props,
            )
            @store.reload!
            @focus_index  = 0
            @queue_scroll = 0
          rescue => e
            print "\nError: #{e.message}\n"
            sleep 1.5
          end
        end

        # Re-enter TUI
        setup_terminal
        render
      end

      def handle_refresh
        @store.reload!
        @focus_index  = 0
        @queue_scroll = 0
        render
      end

      def advance_focus(delta)
        max = [tasks.size - 1, 0].max
        @focus_index = (@focus_index + delta).clamp(0, max)
        update_queue_scroll(delta)
        render
      end

      def update_queue_scroll(delta)
        highlighted = @focus_index - 1
        inner_h     = layout.queue_rows - 2
        queue_max   = [tasks.size - 2, 0].max  # max scroll offset

        if highlighted < 0
          @queue_scroll = 0
        elsif delta > 0
          # Scrolling down: trigger scroll when cursor is within margin of the bottom
          bottom_threshold = @queue_scroll + inner_h - 1 - SCROLL_MARGIN
          if highlighted > bottom_threshold
            @queue_scroll = [highlighted - inner_h + 1 + SCROLL_MARGIN, queue_max].min
          end
        else
          # Scrolling up: trigger scroll when cursor is within margin of the top
          top_threshold = @queue_scroll + SCROLL_MARGIN
          if highlighted < top_threshold
            @queue_scroll = [highlighted - SCROLL_MARGIN, 0].max
          end
        end
      end

      def show_error(msg)
        # Print error at status bar position briefly
        print @cursor.move_to(0, layout.status_top)
        print msg.ljust(layout.width)
        $stdout.flush
        sleep 1.5
        render
      end
    end
  end
end
