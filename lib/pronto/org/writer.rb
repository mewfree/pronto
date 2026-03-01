# frozen_string_literal: true

require "date"
require "time"
require "tempfile"
require "fileutils"

module Pronto
  module Org
    # Surgically mutates .org files without re-serializing the whole document.
    class Writer
      # Mark a task DONE.
      # - Changes the keyword on the headline line.
      # - Inserts or updates CLOSED timestamp on the planning line.
      def mark_done(node, insert_closed: true)
        lines = File.readlines(node.file)

        # 1. Mutate headline line (line_start is 1-based)
        headline_idx = node.line_start - 1
        lines[headline_idx] = update_keyword(lines[headline_idx], node.keyword, "DONE")

        # 2. Handle CLOSED timestamp
        if insert_closed
          planning_idx = find_planning_line(lines, node.line_start, node.line_end)
          closed_str   = "CLOSED: #{inactive_now}"

          if planning_idx
            lines[planning_idx] = update_or_insert_closed(lines[planning_idx], closed_str)
          else
            # Insert new planning line after headline
            indent = "  " * (node.level - 1)
            lines.insert(headline_idx + 1, "#{indent}#{closed_str}\n")
          end
        end

        atomic_write(node.file, lines)
      end

      # Append a new headline task to the end of the file.
      def append_task(file:, title:, keyword: "TODO", priority: nil, scheduled: nil,
                      tags: [], properties: {})
        # Ensure file ends with a newline
        content = File.exist?(file) ? File.read(file) : ""
        content += "\n" unless content.end_with?("\n") || content.empty?

        headline = build_headline(title, keyword, priority, tags)
        planning = build_planning(scheduled)
        props    = build_properties(properties)

        lines = [headline]
        lines << planning if planning
        lines += props unless props.empty?

        File.open(file, "a") do |f|
          f.write("\n") if content.empty? # blank line separator
          f.puts lines
        end
      end

      private

      def update_keyword(line, old_keyword, new_keyword)
        if old_keyword
          line.sub(/\b#{Regexp.escape(old_keyword)}\b/, new_keyword)
        else
          # Insert keyword after stars
          line.sub(/\A(\*+\s+)/, "\\1#{new_keyword} ")
        end
      end

      def find_planning_line(lines, line_start, line_end)
        # Planning line is the line immediately after headline (within the node range)
        (line_start..(line_end - 1)).each do |lineno|
          idx = lineno  # 0-based index = lineno (since line_start is 1-based)
          break if idx >= lines.length

          l = lines[idx]
          return idx if /\A\s*(SCHEDULED|DEADLINE|CLOSED):/.match?(l)
          # Stop if we hit a non-planning, non-empty line (other than drawer)
          break unless l.strip.empty? || /\A\s*:(SCHEDULED|DEADLINE|CLOSED|PROPERTIES|END):/.match?(l)
        end
        nil
      end

      def update_or_insert_closed(planning_line, closed_str)
        if planning_line.include?("CLOSED:")
          planning_line.sub(/CLOSED:\s*\[.*?\]/, closed_str)
        else
          # Prepend CLOSED to existing planning line
          indent = planning_line[/\A\s*/]
          "#{indent}#{closed_str} #{planning_line.lstrip}"
        end
      end

      def inactive_now
        now = Time.now
        now.strftime("[%Y-%m-%d %a %H:%M]")
      end

      def atomic_write(path, lines)
        tmp = "#{path}.pronto.tmp"
        File.write(tmp, lines.join)
        File.rename(tmp, path)
      rescue => e
        File.delete(tmp) if File.exist?(tmp)
        raise e
      end

      def build_headline(title, keyword, priority, tags)
        parts = ["*", keyword, priority ? "[##{priority}]" : nil, title].compact
        tag_str = tags.empty? ? "" : "  :#{tags.join(':')}:"
        "#{parts.join(' ')}#{tag_str}\n"
      end

      def build_planning(scheduled)
        return nil unless scheduled

        ts = case scheduled
             when String then scheduled
             when Date   then "<#{scheduled.strftime('%Y-%m-%d %a')}>"
             when Time   then "<#{scheduled.strftime('%Y-%m-%d %a %H:%M')}>"
             else scheduled.to_s
             end
        "  SCHEDULED: #{ts}\n"
      end

      def build_properties(props)
        return [] if props.empty?

        lines = ["  :PROPERTIES:\n"]
        props.each { |k, v| lines << "  :#{k}: #{v}\n" }
        lines << "  :END:\n"
        lines
      end
    end
  end
end
