# frozen_string_literal: true

require "rspec/matchers/built_in/output"

require_relative "fd_capture"
require_relative "output_report"
require_relative "recording_io"

module RSpec
  module Risky
    module Probe
      module OutputProbe
        THREAD_KEY = :__rspec_risky_output_probe_state
        SUPPRESS_KEY = :__rspec_risky_output_probe_suppressed

        State = Struct.new(
          :report,
          :original_stdout,
          :original_stderr,
          :stdout_proxy,
          :stderr_proxy,
          :allow_warn,
          :fd_captures,
          :previous_state,
          :rule_config,
          keyword_init: true
        )

        module OutputMatcherPatch
          def matches?(block)
            OutputProbe.with_capture_suppressed { super }
          end

          def does_not_match?(block)
            OutputProbe.with_capture_suppressed { super }
          end
        end

        module KernelWarnPatch
          def warn(*messages, **options)
            if OutputProbe.suppress_warn?
              OutputProbe.with_capture_suppressed { super }
            else
              super
            end
          end

          private :warn
        end

        module LoggerPatch
          def add(severity, message = nil, progname = nil, &block)
            OutputProbe.record_logger(self, message, progname, caller_locations(1))
            super
          end
        end

        class << self
          def install
            return if @installed

            ::RSpec::Matchers::BuiltIn::Output.prepend(OutputMatcherPatch)
            ::Kernel.prepend(KernelWarnPatch)
            install_logger_patch

            @installed = true
          end

          def start(rule_config)
            report = Report.new
            state = State.new(
              report: report,
              original_stdout: $stdout,
              original_stderr: $stderr,
              allow_warn: rule_config.allow_warn,
              fd_captures: [],
              rule_config: rule_config,
              previous_state: current
            )

            if rule_config.strict
              start_fd_captures(state, rule_config, report)
            elsif rule_config.captures?(:stdout)
              state.stdout_proxy = RecordingIO.new(:stdout, $stdout, report, passthrough: rule_config.passthrough)
            end
            if !rule_config.strict && rule_config.captures?(:stderr)
              state.stderr_proxy = RecordingIO.new(:stderr, $stderr, report, passthrough: rule_config.passthrough)
            end

            $stdout = state.stdout_proxy if state.stdout_proxy
            $stderr = state.stderr_proxy if state.stderr_proxy
            Thread.current[THREAD_KEY] = state

            state
          end

          def finish(state)
            return unless state

            state.fd_captures.reverse_each(&:finish)
            $stdout = state.original_stdout if state.stdout_proxy
            $stderr = state.original_stderr if state.stderr_proxy
            Thread.current[THREAD_KEY] = state.previous_state

            state.report
          end

          def with_capture_suppressed
            Thread.current[SUPPRESS_KEY] = Thread.current[SUPPRESS_KEY].to_i + 1
            yield
          ensure
            Thread.current[SUPPRESS_KEY] -= 1
          end

          def capture_suppressed?
            Thread.current[SUPPRESS_KEY].to_i.positive?
          end

          def suppress_warn?
            current&.allow_warn
          end

          def record_logger(logger, message, progname, locations)
            state = current
            return unless state

            path = logger_path(logger)
            return unless state.rule_config.captures_logger?(path)

            sample = message || progname || "logger write"
            state.report.record(:logger, sample.to_s, locations)
          end

          private

          def install_logger_patch
            require "logger"
            ::Logger.prepend(LoggerPatch)
          rescue LoadError
            nil
          end

          def start_fd_captures(state, rule_config, report)
            if rule_config.captures?(:stdout)
              state.fd_captures << FdCapture.new(:stdout, $stdout, report, passthrough: rule_config.passthrough).start
            end
            if rule_config.captures?(:stderr)
              state.fd_captures << FdCapture.new(:stderr, $stderr, report, passthrough: rule_config.passthrough).start
            end
          end

          def logger_path(logger)
            logdev = logger.instance_variable_get(:@logdev)
            return unless logdev

            filename = logdev.instance_variable_get(:@filename)
            filename&.to_s
          end

          def current
            Thread.current[THREAD_KEY]
          end
        end
      end
    end
  end
end
