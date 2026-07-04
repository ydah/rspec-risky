# frozen_string_literal: true

require "rspec/core"

module RSpec
  module Risky
    module RSpecCli
      module ParserPatch
        def parser(options)
          super.tap do |parser|
            parser.on("--risky-exit-code CODE", Integer, "Override the exit code used when risky examples pass.") do |code|
              options[:risky_exit_code] = code
            end
          end
        end
      end

      module RunnerPatch
        def exit_code(examples_passed = false)
          code = super
          return code unless code.zero? && examples_passed
          return code unless risky_exit_code
          return code unless RSpec::Risky.risky_results.any? { |_example, result| result[:verdicts].any? }

          risky_exit_code
        end

        private

        def risky_exit_code
          return unless @configuration.respond_to?(:risky_exit_code)

          @configuration.risky_exit_code
        end
      end

      class << self
        def install
          return if @installed

          ::RSpec::Core::Configuration.add_setting :risky_exit_code
          ::RSpec::Core::Parser.prepend(ParserPatch)
          ::RSpec::Core::Runner.prepend(RunnerPatch)

          @installed = true
        end
      end
    end
  end
end
