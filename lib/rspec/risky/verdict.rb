# frozen_string_literal: true

module RSpec
  module Risky
    class RuleResult
      attr_reader :rule, :severity, :message, :evidence

      def initialize(rule:, severity:, message:, evidence:)
        @rule = rule
        @severity = severity
        @message = message
        @evidence = evidence
      end

      def to_h
        {
          rule: rule,
          severity: severity,
          message: message,
          evidence: evidence
        }
      end
    end

    module Verdict
      class << self
        def evaluate(example:, configuration:, expectations:, output:)
          return [] if skip_verdicts?(example)

          verdicts = []
          verdicts << unknown_test_result(configuration, expectations) if evaluate_unknown_test?(example, configuration)
          verdicts << redundant_print_result(configuration, output) if evaluate_redundant_print?(example, configuration, output)
          verdicts.compact
        end

        private

        def skip_verdicts?(example)
          example.exception || example.pending? || example.skipped?
        end

        def evaluate_unknown_test?(example, configuration)
          configuration.rule_enabled?(:unknown_test) && !allowed?(example, :unknown_test)
        end

        def evaluate_redundant_print?(example, configuration, output)
          configuration.rule_enabled?(:redundant_print) &&
            output &&
            !allowed?(example, :redundant_print)
        end

        def unknown_test_result(configuration, expectations)
          assertions = expectations.expectation_count
          assertions += expectations.mock_expectation_count if configuration.unknown_test.count_mocks
          assertions += expectations.custom_expectation_count
          return unless assertions.zero?

          RuleResult.new(
            rule: :unknown_test,
            severity: configuration.unknown_test.severity,
            message: "RISKY (unknown_test): no expectations or mock verifications were executed",
            evidence: {
              custom_expectation_count: expectations.custom_expectation_count,
              expectation_count: expectations.expectation_count,
              mock_expectation_count: expectations.mock_expectation_count
            }
          )
        end

        def redundant_print_result(configuration, output)
          writes = output.writes_for(configuration.redundant_print)
          return if writes.empty?

          RuleResult.new(
            rule: :redundant_print,
            severity: configuration.redundant_print.severity,
            message: "RISKY (redundant_print): example wrote to stdout/stderr",
            evidence: writes.transform_values { |stats| stream_evidence(stats) }
          )
        end

        def stream_evidence(stats)
          {
            write_count: stats.write_count,
            byte_count: stats.byte_count,
            first_location: format_location(stats.first_location),
            first_sample: stats.first_sample
          }
        end

        def format_location(location)
          return unless location

          path = location.path
          path = path.delete_prefix("#{Dir.pwd}/")
          "#{path}:#{location.lineno}"
        end

        def allowed?(example, rule)
          risky_metadata = example.metadata[:risky]
          return false unless risky_metadata

          allowed_rules =
            case risky_metadata
            when Hash
              Array(risky_metadata[:allow])
            when Array
              risky_metadata
            when Symbol, String
              [risky_metadata]
            else
              []
            end

          allowed_rules.map(&:to_sym).include?(rule)
        end
      end
    end
  end
end
