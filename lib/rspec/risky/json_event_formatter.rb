# frozen_string_literal: true

require "json"
require "rspec/core"

module RSpec
  module Risky
    class JsonEventFormatter
      ::RSpec::Core::Formatters.register self, :example_finished

      def initialize(output)
        @output = output
      end

      def example_finished(notification)
        result = notification.example.metadata[:rspec_risky]
        return unless result

        result[:verdicts].each do |verdict|
          @output.write(JSON.generate(event_payload(notification.example, result, verdict)))
          @output.write("\n")
        end
      end

      private

      def event_payload(example, result, verdict)
        {
          event: "rspec_risky.verdict",
          example_id: example.id,
          description: example.full_description,
          location: example.location,
          expectation_count: result[:expectation_count],
          mock_expectation_count: result[:mock_expectation_count],
          custom_expectation_count: result[:custom_expectation_count],
          verdict: verdict.to_h
        }
      end
    end
  end
end
