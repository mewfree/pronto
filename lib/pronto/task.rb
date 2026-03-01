# frozen_string_literal: true

module Pronto
  # Wraps an OrgNode with a computed score and skip metadata.
  class Task
    attr_reader :node, :score
    attr_accessor :skipped_at

    def initialize(node:, score: 0.0)
      @node       = node
      @score      = score
      @skipped_at = nil
    end

    def title        = node.title
    def keyword      = node.keyword
    def priority     = node.priority
    def tags         = node.tags
    def deadline     = node.deadline
    def scheduled    = node.scheduled
    def closed       = node.closed
    def file         = node.file
    def line_start   = node.line_start
    def effort_minutes = node.effort_minutes

    def skipped?
      !@skipped_at.nil?
    end

    def skip!(cooldown_minutes)
      @skipped_at = Time.now + (cooldown_minutes * 60)
    end

    def cooled_down?
      @skipped_at && Time.now >= @skipped_at
    end

    def priority_label
      priority ? "[##{priority}]" : nil
    end

    def effort_label
      mins = effort_minutes
      return nil unless mins

      if mins < 60
        "#{mins}m"
      elsif mins % 60 == 0
        "#{mins / 60}h"
      else
        "#{mins / 60}h#{mins % 60}m"
      end
    end

    def tags_label
      tags.empty? ? nil : ":#{tags.join(':')}:"
    end

    def to_s
      parts = [keyword, priority_label, title, tags_label].compact
      parts.join(" ")
    end
  end
end
