# frozen_string_literal: true

require "rspec/core"
require "rspec/core/formatters/base_text_formatter"
require "rspec/core/formatters/console_codes"

module RSpec
  module Risky
    class Formatter < ::RSpec::Core::Formatters::BaseTextFormatter
      ::RSpec::Core::Formatters.register self,
                                         :example_passed,
                                         :example_pending,
                                         :example_failed,
                                         :start_dump,
                                         :dump_summary

      def initialize(output)
        super
        @examples = []
      end

      def example_passed(notification)
        @examples << notification.example
        marker = risky?(notification.example) ? "R" : "."
        color = risky?(notification.example) ? :pending : :success
        output.print ::RSpec::Core::Formatters::ConsoleCodes.wrap(marker, color)
      end

      def example_pending(notification)
        @examples << notification.example
        output.print ::RSpec::Core::Formatters::ConsoleCodes.wrap("*", :pending)
      end

      def example_failed(notification)
        @examples << notification.example
        output.print ::RSpec::Core::Formatters::ConsoleCodes.wrap("F", :failure)
      end

      def start_dump(_notification)
        output.puts
      end

      def dump_summary(summary)
        dump_risky_examples
        dump_assertion_density
        super
      end

      private

      def risky?(example)
        risky_verdicts(example).any?
      end

      def risky_verdicts(example)
        example.metadata.dig(:rspec_risky, :verdicts) || []
      end

      def dump_risky_examples
        risky_examples = @examples.select { |example| risky?(example) }
        return if risky_examples.empty?

        output.puts
        output.puts "Risky examples:"
        risky_examples.each do |example|
          risky_verdicts(example).each do |verdict|
            output.puts "  #{example.location} #{verdict.message}"
            output.puts "    #{format_evidence(verdict)}"
          end
        end
        output.puts "Risky summary: #{format_rule_counts(risky_examples)}"
      end

      def dump_assertion_density
        counts = @examples.filter_map do |example|
          result = example.metadata[:rspec_risky]
          next unless result

          result[:expectation_count] + result[:mock_expectation_count]
        end
        return if counts.empty?

        sorted = counts.sort
        average = counts.sum.fdiv(counts.length)

        output.puts
        output.puts format(
          "Assertion density: min=%<min>d p50=%<p50>d p90=%<p90>d max=%<max>d avg=%<avg>.2f",
          min: sorted.first,
          p50: percentile(sorted, 0.50),
          p90: percentile(sorted, 0.90),
          max: sorted.last,
          avg: average
        )
      end

      def percentile(sorted, quantile)
        sorted[((sorted.length - 1) * quantile).ceil]
      end

      def format_rule_counts(examples)
        counts = Hash.new(0)
        examples.each do |example|
          risky_verdicts(example).each { |verdict| counts[verdict.rule] += 1 }
        end

        counts.sort_by { |rule, _count| rule.to_s }.map { |rule, count| "#{rule}=#{count}" }.join(", ")
      end

      def format_evidence(verdict)
        case verdict.rule
        when :unknown_test
          "expectations=#{verdict.evidence.fetch(:expectation_count)}, " \
            "mocks=#{verdict.evidence.fetch(:mock_expectation_count)}, " \
            "custom=#{verdict.evidence.fetch(:custom_expectation_count)}"
        when :redundant_print
          verdict.evidence.map do |stream_name, evidence|
            location = evidence[:first_location] || "unknown"
            sample = evidence[:first_sample].to_s.inspect
            "#{stream_name} #{evidence[:write_count]} writes, #{evidence[:byte_count]} bytes; first at #{location} #{sample}"
          end.join("; ")
        else
          verdict.evidence.inspect
        end
      end
    end
  end
end
