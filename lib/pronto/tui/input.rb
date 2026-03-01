# frozen_string_literal: true

require "io/console"

module Pronto
  module TUI
    # Raw keypress reader with escape-sequence parsing for arrow keys.
    module Input
      # Read a single keypress. Returns a symbol or string:
      #   :up, :down, :quit, :done, :skip, :add, :list, :refresh, :next_task, :prev_task
      # or a plain character string for unrecognized keys.
      def self.read_key(timeout: nil)
        if timeout
          ready = IO.select([$stdin], nil, nil, timeout)
          return :timeout unless ready
        end

        ch = $stdin.getch(min: 1, time: 0)
        return nil if ch.nil?

        # Handle escape sequences (arrow keys)
        if ch == "\e"
          rest = read_escape_sequence
          return parse_escape(rest)
        end

        map_key(ch)
      end

      # Enable raw mode for the duration of the block.
      def self.with_raw_input
        $stdin.raw do
          yield
        end
      end

      private_class_method def self.read_escape_sequence
        # Non-blocking reads for the rest of the escape sequence
        buf = ""
        2.times do
          ready = IO.select([$stdin], nil, nil, 0.05)
          break unless ready

          c = $stdin.getch(min: 1, time: 0)
          buf += c if c
        end
        buf
      end

      private_class_method def self.parse_escape(seq)
        case seq
        when "[A" then :up
        when "[B" then :down
        when "[C" then :right
        when "[D" then :left
        else          :escape
        end
      end

      private_class_method def self.map_key(ch)
        case ch
        when "q", "\x03" then :quit   # q or Ctrl-C
        when "d"          then :done
        when "s"          then :skip
        when "a"          then :add
        when "l"          then :list
        when "r"          then :refresh
        when "n"          then :down
        when "p"          then :up
        when "k"          then :up
        when "j"          then :down
        when "\r", "\n"   then :select
        else ch
        end
      end
    end
  end
end
