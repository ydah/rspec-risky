# frozen_string_literal: true

require "json"
require "rspec/core"

module RSpec
  module Risky
    class JsonFormatter
      ::RSpec::Core::Formatters.register self, :dump_summary

      def initialize(output)
        @output = output
      end

      def dump_summary(summary)
        @output.write(JSON.pretty_generate(payload(summary)))
        @output.write("\n")
      end

      private

      def payload(summary)
        risky_examples = RSpec::Risky.risky_results.select { |_example, result| result[:verdicts].any? }

        {
          summary: summary_payload(summary, risky_examples),
          examples: risky_examples.map { |example, result| example_payload(example, result) }
        }
      end

      def summary_payload(summary, risky_examples)
        {
          duration: summary.duration,
          example_count: summary.example_count,
          failure_count: summary.failure_count,
          pending_count: summary.pending_count,
          risky_count: risky_examples.length,
          risky_rules: rule_counts(risky_examples)
        }
      end

      def example_payload(example, result)
        {
          id: example.id,
          description: example.full_description,
          location: example.location,
          custom_expectation_count: result[:custom_expectation_count],
          expectation_count: result[:expectation_count],
          mock_expectation_count: result[:mock_expectation_count],
          verdicts: result[:verdicts].map(&:to_h)
        }
      end

      def rule_counts(risky_examples)
        risky_examples.each_with_object(Hash.new(0)) do |(_example, result), counts|
          result[:verdicts].each { |verdict| counts[verdict.rule] += 1 }
        end
      end
    end
  end
end
