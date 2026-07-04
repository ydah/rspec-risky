# frozen_string_literal: true

module RSpec
  module Risky
    class Configuration
      VALID_RULES = %i[unknown_test redundant_print].freeze

      attr_reader :unknown_test, :redundant_print

      def initialize
        @rules = VALID_RULES.dup
        @unknown_test = UnknownTestConfig.new
        @redundant_print = RedundantPrintConfig.new
      end

      def rules
        @rules.dup
      end

      def rules=(rules)
        selected_rules = Array(rules).map(&:to_sym)
        unknown_rules = selected_rules - VALID_RULES
        raise ArgumentError, "unknown risky rules: #{unknown_rules.join(", ")}" if unknown_rules.any?

        @rules = selected_rules
      end

      def rule_enabled?(rule)
        @rules.include?(rule.to_sym)
      end
    end

    class RuleConfig
      VALID_SEVERITIES = %i[risky fail].freeze

      attr_reader :severity

      def initialize
        @severity = :risky
      end

      def severity=(severity)
        value = severity.to_sym
        unless VALID_SEVERITIES.include?(value)
          raise ArgumentError, "severity must be one of: #{VALID_SEVERITIES.join(", ")}"
        end

        @severity = value
      end
    end

    class UnknownTestConfig < RuleConfig
      attr_accessor :adapters, :count_mocks

      def initialize
        super
        @adapters = []
        @count_mocks = true
      end

      def adapter_count(example)
        adapters.sum do |adapter|
          Integer(adapter.call(example))
        rescue StandardError
          0
        end
      end
    end

    class RedundantPrintConfig < RuleConfig
      VALID_CAPTURE = %i[stdout stderr both].freeze

      attr_accessor :allow_warn, :capture_loggers, :logger_ignore_paths, :passthrough, :strict
      attr_reader :capture

      def initialize
        super
        @capture = :both
        @allow_warn = false
        @capture_loggers = false
        @logger_ignore_paths = ["log/test.log"]
        @passthrough = true
        @strict = false
      end

      def capture=(capture)
        value = capture.to_sym
        unless VALID_CAPTURE.include?(value)
          raise ArgumentError, "capture must be one of: #{VALID_CAPTURE.join(", ")}"
        end

        @capture = value
      end

      def captures?(stream_name)
        capture == :both || capture == stream_name.to_sym
      end

      def captures_logger?(path)
        capture_loggers && !ignored_logger_path?(path)
      end

      private

      def ignored_logger_path?(path)
        return false unless path

        logger_ignore_paths.any? { |ignored_path| path.end_with?(ignored_path) }
      end
    end
  end
end
