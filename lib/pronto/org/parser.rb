# frozen_string_literal: true

require "date"

module Pronto
  module Org
    # Stateful line-by-line .org file parser.
    # Produces an array of OrgNode objects for each headline found.
    class Parser
      HEADLINE_RE    = /\A(\*+)\s+(?:([A-Z]{2,})\s+)?(?:\[#([ABC])\]\s+)?(.+?)\s*(?::([^:\s][^:]*(?::[^:\s][^:]*)*):)?\s*\z/
      PLANNING_RE    = /\A\s*(SCHEDULED|DEADLINE|CLOSED):\s*/
      DRAWER_START_RE = /\A\s*:([^:]+):\s*\z/
      DRAWER_END_RE   = /\A\s*:END:\s*\z/i
      PROPERTY_RE    = /\A\s*:([^:]+):\s+(.*?)\s*\z/
      TODO_KEYWORD_RE = /\A#\+TODO:\s+(.+)/i

      def initialize(active_keywords: %w[TODO NEXT WAITING], done_keywords: %w[DONE CANCELLED])
        @active_keywords = active_keywords.map(&:upcase)
        @done_keywords   = done_keywords.map(&:upcase)
        @all_keywords    = @active_keywords + @done_keywords
      end

      # Parse a file and return array of OrgNode
      def parse_file(path)
        lines = File.readlines(path, chomp: true)
        parse_lines(lines, path)
      end

      # Parse an array of strings (without trailing newlines) from +path+
      def parse_lines(lines, path = nil)
        nodes    = []
        current  = nil
        in_drawer = false
        in_properties = false

        lines.each_with_index do |line, idx|
          lineno = idx + 1

          # In-buffer TODO keyword override
          if (m = TODO_KEYWORD_RE.match(line))
            parse_todo_keywords(m[1])
            next
          end

          # New headline
          if (m = HEADLINE_RE.match(line))
            keyword = m[2]&.upcase
            # Only treat as keyword if recognized
            unless keyword.nil? || @all_keywords.include?(keyword)
              # It's part of the title
              keyword = nil
            end

            # Commit the previous node
            if current
              current[:line_end] = lineno - 1
              nodes << build_node(current, path)
            end

            raw_title = m[4]
            # If keyword was not recognized, prepend it back to title
            if m[2] && keyword.nil?
              raw_title = "#{m[2]} #{raw_title}"
            end

            current = {
              line_start:  lineno,
              line_end:    lineno,
              level:       m[1].length,
              keyword:     keyword,
              priority:    m[3],
              title:       raw_title.strip,
              tags:        parse_tags(m[5]),
              scheduled:   nil,
              deadline:    nil,
              closed:      nil,
              properties:  {},
              body_lines:  [],
              in_planning: false,
              in_props:    false,
            }
            in_drawer = false
            in_properties = false
            next
          end

          next unless current

          # PROPERTIES drawer
          if DRAWER_END_RE.match?(line)
            in_drawer = false
            in_properties = false
            next
          end

          if in_properties
            if (m = PROPERTY_RE.match(line))
              current[:properties][m[1]] = m[2]
            end
            next
          end

          if in_drawer
            # Inside a non-properties drawer — store as body
            current[:body_lines] << line
            next
          end

          if (m = DRAWER_START_RE.match(line))
            drawer_name = m[1].upcase
            if drawer_name == "PROPERTIES"
              in_properties = true
            else
              in_drawer = true
              current[:body_lines] << line
            end
            next
          end

          # Planning line (SCHEDULED/DEADLINE/CLOSED)
          if PLANNING_RE.match?(line)
            parse_planning_line(line, current)
            next
          end

          current[:body_lines] << line
        end

        # Commit last node
        if current
          current[:line_end] = lines.length
          nodes << build_node(current, path)
        end

        nodes
      end

      private

      def parse_todo_keywords(str)
        # Format: "TODO NEXT | DONE CANCELLED"
        parts = str.split("|")
        active = parts[0]&.split&.map(&:upcase) || []
        done   = parts[1]&.split&.map(&:upcase) || []
        @active_keywords = (@active_keywords + active).uniq
        @done_keywords   = (@done_keywords + done).uniq
        @all_keywords    = @active_keywords + @done_keywords
      end

      def parse_tags(raw)
        return [] if raw.nil? || raw.empty?

        raw.split(":").reject(&:empty?)
      end

      def parse_planning_line(line, node)
        rest = line.dup
        while (m = /\b(SCHEDULED|DEADLINE|CLOSED):\s*(\[.*?\]|<.*?>)/.match(rest))
          ts = Timestamp.parse(m[2])
          case m[1]
          when "SCHEDULED" then node[:scheduled] = ts
          when "DEADLINE"  then node[:deadline]  = ts
          when "CLOSED"    then node[:closed]    = ts
          end
          rest = rest[m.end(0)..]
        end
      end

      def build_node(hash, path)
        OrgNode.new(
          file:       path,
          line_start: hash[:line_start],
          line_end:   hash[:line_end],
          level:      hash[:level],
          keyword:    hash[:keyword],
          priority:   hash[:priority],
          title:      hash[:title],
          tags:       hash[:tags],
          scheduled:  hash[:scheduled],
          deadline:   hash[:deadline],
          closed:     hash[:closed],
          properties: hash[:properties],
          body_lines: hash[:body_lines],
        )
      end
    end
  end
end
