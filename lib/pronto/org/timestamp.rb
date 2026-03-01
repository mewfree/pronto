# frozen_string_literal: true

module Pronto
  module Org
    # Parses and represents an org-mode timestamp.
    # Supports both active <...> and inactive [...] forms.
    # Examples:
    #   <2024-01-15 Mon>
    #   <2024-01-15 Mon 14:30>
    #   [2024-01-15 Mon]
    class Timestamp
      ACTIVE_RE   = /<(\d{4}-\d{2}-\d{2})(?:\s+\w+)?(?:\s+(\d{2}:\d{2}))?>/
      INACTIVE_RE = /\[(\d{4}-\d{2}-\d{2})(?:\s+\w+)?(?:\s+(\d{2}:\d{2}))?\]/

      attr_reader :date, :time, :active, :raw

      def initialize(date:, time: nil, active: true, raw: nil)
        @date   = date   # Date object
        @time   = time   # Time object or nil
        @active = active
        @raw    = raw
      end

      def self.parse(str)
        return nil if str.nil? || str.empty?

        if (m = ACTIVE_RE.match(str))
          active = true
        elsif (m = INACTIVE_RE.match(str))
          active = false
        else
          return nil
        end

        date = Date.parse(m[1])
        time = m[2] ? Time.parse("#{m[1]} #{m[2]}") : nil
        new(date: date, time: time, active: active, raw: m[0])
      rescue ArgumentError
        nil
      end

      def to_s
        date_str = date.strftime("%Y-%m-%d %a")
        time_str = time ? " #{time.strftime('%H:%M')}" : ""
        if active
          "<#{date_str}#{time_str}>"
        else
          "[#{date_str}#{time_str}]"
        end
      end

      # Days from today until this timestamp (negative = past)
      def days_until
        (date - Date.today).to_i
      end

      def past?
        days_until < 0
      end

      def today?
        days_until == 0
      end

      def overdue?
        past?
      end
    end
  end
end
