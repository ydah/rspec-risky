# frozen_string_literal: true

module RSpec
  module Risky
    module Probe
      module OutputProbe
        class Report
          attr_reader :streams

          def initialize
            @streams = {
              logger: StreamStats.new(:logger),
              stdout: StreamStats.new(:stdout),
              stderr: StreamStats.new(:stderr)
            }
          end

          def record(stream_name, data, locations)
            streams.fetch(stream_name).record(data.to_s, first_application_location(locations))
          end

          def writes_for(rule_config)
            streams.select do |stream_name, stats|
              captured_stream?(rule_config, stream_name) && stats.written?
            end
          end

          private

          def captured_stream?(rule_config, stream_name)
            return rule_config.capture_loggers if stream_name == :logger

            rule_config.captures?(stream_name)
          end

          def first_application_location(locations)
            locations.find do |location|
              path = location.path
              !path.include?("/rspec/risky/") &&
                !path.include?("/rspec-core-") &&
                !path.include?("/rspec-expectations-") &&
                !path.include?("/rspec-mocks-")
            end || locations.first
          end
        end

        class StreamStats
          attr_reader :stream_name, :write_count, :byte_count, :first_location, :first_sample

          def initialize(stream_name)
            @stream_name = stream_name
            @write_count = 0
            @byte_count = 0
            @first_location = nil
            @first_sample = nil
          end

          def record(data, location)
            @write_count += 1
            @byte_count += data.bytesize
            @first_location ||= location
            @first_sample ||= data.byteslice(0, 200)
          end

          def written?
            write_count.positive?
          end
        end
      end
    end
  end
end
