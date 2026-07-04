# frozen_string_literal: true

module RSpec
  module Risky
    module Probe
      module OutputProbe
        class FdCapture
          READ_SIZE = 4096

          def initialize(stream_name, io, report, passthrough:)
            @stream_name = stream_name
            @io = io
            @report = report
            @passthrough = passthrough
            @reader = nil
            @original = nil
            @thread = nil
          end

          def start
            @original = @io.dup
            @reader, writer = IO.pipe
            @reader.binmode
            writer.binmode
            @io.reopen(writer)
            @io.sync = true if @io.respond_to?(:sync=)
            writer.close
            start_reader
            self
          end

          def finish
            @io.reopen(@original) if @original
            @thread&.join(1)
            @original&.close
          ensure
            @reader&.close unless @reader&.closed?
          end

          private

          def start_reader
            @thread = Thread.new do
              drain_reader
            end
          end

          def drain_reader
            loop do
              chunk = @reader.readpartial(READ_SIZE)
              @report.record(@stream_name, chunk, [])
              @original.write(chunk) if @passthrough
            end
          rescue EOFError, IOError
            nil
          end
        end
      end
    end
  end
end
