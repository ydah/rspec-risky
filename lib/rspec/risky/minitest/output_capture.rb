# frozen_string_literal: true

require_relative "../probe/output_report"

module RSpec
  module Risky
    module Minitest
      module Plugin
        class OutputCapture
          ALLOW_WARN_KEY = :__rspec_risky_minitest_allow_warn
          SUPPRESS_KEY = :__rspec_risky_minitest_output_suppressed

          State = Struct.new(:original_stderr, :original_stdout, :report, :stderr_proxy, :stdout_proxy, keyword_init: true)

          module KernelWarnPatch
            def warn(*messages, **options)
              if OutputCapture.allow_warn?
                OutputCapture.with_suppressed { super }
              else
                super
              end
            end

            private :warn
          end

          class Stream
            def initialize(stream_name, io, report)
              @stream_name = stream_name
              @io = io
              @report = report
            end

            def write(data)
              return @io.write(data) if OutputCapture.suppressed?

              @report.record(@stream_name, data.to_s, caller_locations(1))
              @io.write(data)
            end

            def <<(data)
              write(data)
              self
            end

            def puts(*objects)
              data = objects.empty? ? "\n" : objects.map { |object| "#{object}\n" }.join
              @report.record(@stream_name, data, caller_locations(1)) unless OutputCapture.suppressed?
              @io.puts(*objects)
            end

            def print(*objects)
              data = objects.empty? ? $_.to_s : objects.map(&:to_s).join($,)
              @report.record(@stream_name, data, caller_locations(1)) unless OutputCapture.suppressed?
              @io.print(*objects)
            end

            def method_missing(method_name, *args, &block)
              return super unless @io.respond_to?(method_name)

              @io.public_send(method_name, *args, &block)
            end

            def respond_to_missing?(method_name, include_private = false)
              @io.respond_to?(method_name, include_private) || super
            end
          end

          def self.install
            return if @installed

            ::Kernel.prepend(KernelWarnPatch)
            @installed = true
          end

          def self.start(allow_warn: false)
            report = Probe::OutputProbe::Report.new
            state = State.new(original_stderr: $stderr, original_stdout: $stdout, report: report)
            state.stdout_proxy = Stream.new(:stdout, $stdout, report)
            state.stderr_proxy = Stream.new(:stderr, $stderr, report)
            $stdout = state.stdout_proxy
            $stderr = state.stderr_proxy
            Thread.current[ALLOW_WARN_KEY] = allow_warn
            state
          end

          def self.finish(state)
            return unless state

            $stdout = state.original_stdout if $stdout.equal?(state.stdout_proxy)
            $stderr = state.original_stderr if $stderr.equal?(state.stderr_proxy)
            Thread.current[ALLOW_WARN_KEY] = false
            state.report
          end

          def self.allow_warn?
            Thread.current[ALLOW_WARN_KEY]
          end

          def self.suppressed?
            Thread.current[SUPPRESS_KEY].to_i.positive?
          end

          def self.with_suppressed
            Thread.current[SUPPRESS_KEY] = Thread.current[SUPPRESS_KEY].to_i + 1
            yield
          ensure
            Thread.current[SUPPRESS_KEY] -= 1
          end
        end
      end
    end
  end
end
