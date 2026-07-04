# frozen_string_literal: true

require "rspec/core"

require_relative "risky/version"
require_relative "risky/configuration"
require_relative "risky/probe/expectation_probe"
require_relative "risky/probe/output_probe"
require_relative "risky/rspec_cli"
require_relative "risky/verdict"
require_relative "risky/formatter"
require_relative "risky/json_event_formatter"
require_relative "risky/json_formatter"

module RSpec
  module Risky
    class Error < StandardError; end

    class RiskyExampleError < Error
      attr_reader :verdicts

      def initialize(verdicts)
        @verdicts = verdicts
        super(verdicts.map(&:message).join("\n"))
      end
    end

    class << self
      attr_writer :configuration

      def configuration
        @configuration ||= Configuration.new
      end

      def record_expectation(count = 1)
        Probe::ExpectationProbe.record_custom_expectation(count)
      end

      def configure(rspec_configuration = nil)
        yield configuration if block_given?

        install!
        integrate!(rspec_configuration || default_rspec_configuration)

        configuration
      end

      def install!
        return if @installed

        Probe::ExpectationProbe.install
        Probe::OutputProbe.install
        RSpecCli.install

        @installed = true
      end

      def run_example(example_procsy)
        example = example_procsy.example
        expectation_state = Probe::ExpectationProbe.start(example)
        output_state = start_output_probe

        begin
          example_procsy.run
        ensure
          output_report = Probe::OutputProbe.finish(output_state)
          expectation_report = Probe::ExpectationProbe.finish(expectation_state)
          expectation_report.custom_expectation_count += configuration.unknown_test.adapter_count(example)
          verdicts = Verdict.evaluate(
            example: example,
            configuration: configuration,
            expectations: expectation_report,
            output: output_report
          )

          example.metadata[:rspec_risky] = {
            custom_expectation_count: expectation_report.custom_expectation_count,
            expectation_count: expectation_report.expectation_count,
            mock_expectation_count: expectation_report.mock_expectation_count,
            output: output_report,
            verdicts: verdicts
          }
        end

        fail_verdicts = verdicts.select { |verdict| verdict.severity == :fail }
        raise RiskyExampleError.new(fail_verdicts) if fail_verdicts.any? && !example.exception
      end

      def risky_results
        return [] unless defined?(::RSpec::Core)

        ::RSpec.world.all_examples.filter_map do |example|
          result = example.metadata[:rspec_risky]
          next unless result

          [example, result]
        end
      end

      private

      def default_rspec_configuration
        return unless defined?(::RSpec.configuration)

        ::RSpec.configuration
      end

      def integrate!(rspec_configuration)
        return unless rspec_configuration

        @integrated_configurations ||= {}
        return if @integrated_configurations[rspec_configuration.object_id]

        rspec_configuration.around(:example) do |example|
          RSpec::Risky.run_example(example)
        end

        @integrated_configurations[rspec_configuration.object_id] = true
      end

      def start_output_probe
        return unless configuration.rule_enabled?(:redundant_print)

        Probe::OutputProbe.start(configuration.redundant_print)
      end
    end
  end
end
