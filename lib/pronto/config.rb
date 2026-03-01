# frozen_string_literal: true

require "yaml"
require "pathname"

module Pronto
  class Config
    CONFIG_PATH = File.expand_path("~/.config/pronto/config.yml")

    DEFAULTS = {
      "files"        => ["~/org/inbox.org"],
      "default_file" => "~/org/inbox.org",
      "todo_keywords" => {
        "active" => %w[TODO NEXT WAITING],
        "done"   => %w[DONE CANCELLED],
      },
      "insert_closed_timestamp" => true,
      "scoring" => {
        "weights" => {
          "deadline"  => 0.40,
          "priority"  => 0.25,
          "scheduled" => 0.20,
          "age"       => 0.10,
          "effort"    => 0.05,
        },
        "skip_cooldown_minutes" => 30,
        "tag_rules" => [],
      },
      "ui" => {
        "focus_panel_height_pct" => 0.40,
        "show_scores"            => true,
      },
    }.freeze

    attr_reader :raw

    def initialize(path = CONFIG_PATH)
      @raw = load_config(path)
    end

    def files
      Array(@raw["files"]).map { |f| File.expand_path(f) }
    end

    def default_file
      File.expand_path(@raw["default_file"])
    end

    def active_keywords
      @raw.dig("todo_keywords", "active") || DEFAULTS.dig("todo_keywords", "active")
    end

    def done_keywords
      @raw.dig("todo_keywords", "done") || DEFAULTS.dig("todo_keywords", "done")
    end

    def insert_closed_timestamp?
      @raw.fetch("insert_closed_timestamp", true)
    end

    def scoring
      @scoring ||= ScoringConfig.new(@raw.fetch("scoring", {}))
    end

    def ui
      @ui ||= UIConfig.new(@raw.fetch("ui", {}))
    end

    private

    def load_config(path)
      if File.exist?(path)
        user = YAML.safe_load_file(path) || {}
        deep_merge(DEFAULTS, user)
      else
        DEFAULTS.dup
      end
    end

    def deep_merge(base, override)
      base.merge(override) do |_key, old_val, new_val|
        if old_val.is_a?(Hash) && new_val.is_a?(Hash)
          deep_merge(old_val, new_val)
        else
          new_val
        end
      end
    end

    class ScoringConfig
      attr_reader :raw

      def initialize(raw)
        @raw = raw
      end

      def weights
        w = @raw.fetch("weights", {})
        defaults = Pronto::Config::DEFAULTS.dig("scoring", "weights")
        merged = defaults.merge(w)
        # Normalize weights to sum to 1.0
        total = merged.values.sum.to_f
        total = 1.0 if total.zero?
        merged.transform_values { |v| v / total }
      end

      def skip_cooldown_minutes
        @raw.fetch("skip_cooldown_minutes", 30)
      end

      def tag_rules
        @raw.fetch("tag_rules", [])
      end
    end

    class UIConfig
      attr_reader :raw

      def initialize(raw)
        @raw = raw
      end

      def focus_panel_height_pct
        @raw.fetch("focus_panel_height_pct", 0.40)
      end

      def show_scores?
        @raw.fetch("show_scores", true)
      end
    end
  end
end
