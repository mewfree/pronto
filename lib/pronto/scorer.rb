# frozen_string_literal: true

require "date"
require "time"

module Pronto
  # Computes a priority score [0, 1] for each OrgNode.
  class Scorer
    def initialize(config)
      @weights   = config.scoring.weights
      @tag_rules = config.scoring.tag_rules
    end

    # Returns a float score in [0, 1]
    def score(node)
      factors = {
        "deadline"  => deadline_score(node.deadline),
        "priority"  => priority_score(node.priority),
        "scheduled" => scheduled_score(node.scheduled),
        "age"       => age_score(node.created_date),
        "effort"    => effort_score(node.effort_minutes),
      }

      base = factors.sum { |k, v| (@weights[k] || 0.0) * v }
      tag_multiplier = compute_tag_multiplier(node.tags)
      (base * tag_multiplier).clamp(0.0, 1.0)
    end

    private

    # Logistic curve: overdue=1.0, today≈0.8, +7d≈0.1
    def deadline_score(deadline)
      return 0.0 unless deadline

      days = deadline.days_until
      # Logistic: 1 / (1 + e^(0.7 * days - 0.5))
      1.0 / (1.0 + Math.exp(0.7 * days - 0.5))
    end

    def priority_score(priority)
      case priority
      when "A" then 1.0
      when "B" then 0.6
      when "C" then 0.3
      else          0.1
      end
    end

    # past/today→1.0, tomorrow→0.5, future→0.0
    def scheduled_score(scheduled)
      return 0.0 unless scheduled

      days = scheduled.days_until
      if days <= 0
        1.0
      elsif days == 1
        0.5
      else
        0.0
      end
    end

    # log-scale over 30 days — prevents starvation
    def age_score(created_date)
      return 0.1 unless created_date

      age_days = (Date.today - created_date).to_i.clamp(0, 365)
      # Normalize: 0 days → 0.0, 30 days → ~1.0, capped
      (Math.log(age_days + 1) / Math.log(31)).clamp(0.0, 1.0)
    end

    # Quick-win bias: shorter tasks score higher
    def effort_score(minutes)
      return 0.5 unless minutes  # unknown effort → neutral

      if minutes <= 30
        1.0
      elsif minutes <= 60
        0.7
      elsif minutes <= 120
        0.4
      else
        0.1
      end
    end

    def compute_tag_multiplier(tags)
      now = Time.now
      current_hour_min = now.strftime("%H:%M")

      multiplier = 1.0
      @tag_rules.each do |rule|
        next unless in_hour_range?(current_hour_min, rule["during_hours"])

        boost_tags    = Array(rule["boost_tags"])
        suppress_tags = Array(rule["suppress_tags"])

        if tags.any? { |t| boost_tags.include?(t) }
          multiplier *= 1.3
        end

        if tags.any? { |t| suppress_tags.include?(t) }
          multiplier *= 0.5
        end
      end

      multiplier
    end

    def in_hour_range?(current, range_str)
      return false unless range_str

      parts = range_str.split("-")
      return false unless parts.length == 2

      start_t, end_t = parts
      current >= start_t && current < end_t
    end
  end
end
