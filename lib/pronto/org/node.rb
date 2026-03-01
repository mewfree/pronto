# frozen_string_literal: true

module Pronto
  module Org
    # Value object representing a single org-mode headline (task).
    # line_start and line_end are 1-based line numbers in the source file.
    OrgNode = Struct.new(
      :file,
      :line_start,
      :line_end,
      :level,       # Integer: heading depth (1 = *, 2 = **, etc.)
      :keyword,     # String: TODO, DONE, NEXT, etc., or nil
      :priority,    # String: "A", "B", "C", or nil
      :title,       # String: headline text
      :tags,        # Array<String>
      :scheduled,   # Timestamp or nil
      :deadline,    # Timestamp or nil
      :closed,      # Timestamp or nil
      :properties,  # Hash<String, String>
      :body_lines,  # Array<String>: raw body text (excludes planning/drawer lines)
      keyword_init: true
    ) do
      def done?
        keyword && %w[DONE CANCELLED].include?(keyword.upcase)
      end

      def active?
        keyword && !done?
      end

      def effort_minutes
        effort = properties&.dig("EFFORT") || properties&.dig("Effort")
        return nil unless effort

        parse_effort(effort)
      end

      def created_date
        raw = properties&.dig("CREATED") || properties&.dig("Created")
        return nil unless raw

        ts = Timestamp.parse(raw)
        ts&.date
      end

      private

      def parse_effort(str)
        case str
        when /\A(\d+):(\d{2})\z/
          $1.to_i * 60 + $2.to_i
        when /\A(\d+)h(?:\s*(\d+)m?)?\z/i
          $1.to_i * 60 + ($2&.to_i || 0)
        when /\A(\d+)m\z/i
          $1.to_i
        end
      end
    end
  end
end
