# frozen_string_literal: true

require "minitest"

require_relative "../configuration"
require_relative "output_capture"
require_relative "reporter"

module RSpec
  module Risky
    module Minitest
      module Plugin
        METADATA_KEY = "rspec_risky"

        Result = Struct.new(:rule, :message, :evidence, keyword_init: true) do
          def to_h
            { rule: rule, message: message, evidence: evidence }
          end
        end

        module RunnablePatch
          def run
            config = Plugin.configuration
            output_state = config[:redundant_print] ? OutputCapture.start(allow_warn: config[:allow_warn]) : nil

            super.tap do |result|
              output_report = OutputCapture.finish(output_state)
              output_state = nil
              verdicts = Plugin.verdicts_for(result, output_report, config)
              next if verdicts.empty?

              result.metadata[METADATA_KEY] = verdicts.map(&:to_h)
              result.failures << ::Minitest::Assertion.new(verdicts.map(&:message).join("\n")) if config[:fail]
            end
          ensure
            OutputCapture.finish(output_state) if output_state
          end
        end

        class << self
          attr_reader :configuration

          def install(configuration)
            @configuration = configuration
            OutputCapture.install
            install_runner_patch unless @installed
            ::Minitest.reporter << Reporter.new(::Minitest.reporter.io, configuration)
            @installed = true
          end

          def verdicts_for(result, output_report, config)
            return [] unless result.passed?

            verdicts = []
            verdicts << unknown_test_result(result) if config[:unknown_test] && result.assertions.zero?
            if config[:redundant_print] && output_report
              verdicts << redundant_print_result(output_report)
            end
            verdicts.compact
          end

          private

          def install_runner_patch
            if defined?(::Minitest::Test)
              ::Minitest::Test.prepend(RunnablePatch)
            else
              ::Minitest::Runnable.prepend(RunnablePatch)
            end
          end

          def unknown_test_result(result)
            Result.new(
              rule: :unknown_test,
              message: "no assertions were executed",
              evidence: { assertion_count: result.assertions }
            )
          end

          def redundant_print_result(output_report)
            config = RedundantPrintConfig.new
            writes = output_report.writes_for(config)
            return if writes.empty?

            Result.new(
              rule: :redundant_print,
              message: "test wrote to stdout/stderr",
              evidence: writes.transform_values { |stats| stream_evidence(stats) }
            )
          end

          def stream_evidence(stats)
            {
              byte_count: stats.byte_count,
              first_sample: stats.first_sample,
              write_count: stats.write_count
            }
          end
        end
      end
    end
  end
end
