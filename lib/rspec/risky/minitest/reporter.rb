# frozen_string_literal: true

module RSpec
  module Risky
    module Minitest
      module Plugin
        class Reporter < ::Minitest::Reporter
          def initialize(io = $stdout, options = {})
            super
            @risky_results = []
          end

          def record(result)
            verdicts = result.metadata[METADATA_KEY]
            return unless verdicts

            @risky_results << [result, verdicts]
          end

          def report
            return if @risky_results.empty?

            io.puts
            io.puts "Risky tests:"
            @risky_results.each do |result, verdicts|
              verdicts.each do |verdict|
                io.puts "  #{result.location} RISKY (#{verdict.fetch(:rule)}) #{verdict.fetch(:message)}"
              end
            end
            io.puts "Risky summary: #{summary}"
          end

          private

          def summary
            counts = Hash.new(0)
            @risky_results.each do |_result, verdicts|
              verdicts.each { |verdict| counts[verdict.fetch(:rule)] += 1 }
            end
            counts.sort_by { |rule, _count| rule.to_s }.map { |rule, count| "#{rule}=#{count}" }.join(", ")
          end
        end
      end
    end
  end
end
