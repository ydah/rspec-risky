# frozen_string_literal: true

module RSpec
  module Risky
    module Probe
      module OutputProbe
        class RecordingIO
          def initialize(stream_name, io, report, passthrough:)
            @stream_name = stream_name
            @io = io
            @report = report
            @passthrough = passthrough
          end

          def write(data)
            record(data, caller_locations(1))
            @io.write(data) if @passthrough
          end

          def write_nonblock(data, *args)
            record(data, caller_locations(1))
            return data.bytesize unless @passthrough

            @io.write_nonblock(data, *args)
          end

          def <<(data)
            write(data)
            self
          end

          def puts(*objects)
            data = objects.empty? ? "\n" : objects.map { |object| "#{format_puts_object(object)}\n" }.join
            record(data, caller_locations(1))
            @io.puts(*objects) if @passthrough
          end

          def print(*objects)
            data = objects.empty? ? $_.to_s : objects.map(&:to_s).join($,)
            data = "#{data}#{$OUTPUT_RECORD_SEPARATOR}" if $OUTPUT_RECORD_SEPARATOR
            record(data, caller_locations(1))
            @io.print(*objects) if @passthrough
          end

          def printf(format_string, *arguments)
            data = format(format_string, *arguments)
            record(data, caller_locations(1))
            @io.printf(format_string, *arguments) if @passthrough
          end

          def flush
            @io.flush if @io.respond_to?(:flush)
          end

          def sync
            @io.sync if @io.respond_to?(:sync)
          end

          def sync=(value)
            @io.sync = value if @io.respond_to?(:sync=)
          end

          def tty?
            @io.tty? if @io.respond_to?(:tty?)
          end
          alias isatty tty?

          def clone
            @io.clone
          end

          def dup
            @io.dup
          end

          def method_missing(method_name, *args, &block)
            return super unless @io.respond_to?(method_name)

            @io.public_send(method_name, *args, &block)
          end

          def respond_to_missing?(method_name, include_private = false)
            @io.respond_to?(method_name, include_private) || super
          end

          private

          def record(data, locations)
            return if OutputProbe.capture_suppressed?

            @report.record(@stream_name, data, locations)
          end

          def format_puts_object(object)
            case object
            when nil
              "nil"
            when Array
              object.map { |item| format_puts_object(item) }.join("\n")
            else
              object.to_s
            end
          end
        end
      end
    end
  end
end
