# frozen_string_literal: true

require "json"

module RSpec
  module Risky
    module Evaluation
      class << self
        def compare(static_findings:, dynamic_payload:)
          static = static_findings.map { |finding| normalize_static(finding) }
          dynamic = dynamic_payload.fetch("examples", []).flat_map { |example| normalize_dynamic(example) }

          {
            dynamic_only: dynamic - static,
            dynamic_total: dynamic.length,
            overlap: dynamic & static,
            static_only: static - dynamic,
            static_total: static.length
          }
        end

        def assertion_density(dynamic_payload)
          counts = dynamic_payload.fetch("examples", []).map do |example|
            example.fetch("expectation_count", 0) +
              example.fetch("mock_expectation_count", 0) +
              example.fetch("custom_expectation_count", 0)
          end
          return {} if counts.empty?

          sorted = counts.sort
          {
            average: counts.sum.fdiv(counts.length),
            max: sorted.last,
            min: sorted.first,
            p50: percentile(sorted, 0.50),
            p90: percentile(sorted, 0.90)
          }
        end

        def label_template(dynamic_payload)
          dynamic_payload.fetch("examples", []).flat_map do |example|
            example.fetch("verdicts", []).map do |verdict|
              {
                location: example.fetch("location"),
                rule: verdict.fetch("rule").to_s,
                label: nil,
                allowed_labels: %w[intentional_smoke true_missing_oracle false_positive],
                description: example["description"]
              }
            end
          end
        end

        def mutation_study(dynamic_payload, mutation_payload = nil)
          density = assertion_density(dynamic_payload)
          scores = mutation_payload ? mutation_scores(dynamic_payload, mutation_payload) : []
          return { assertion_density: density, mutation_correlation: nil, mutation_samples: 0 } if scores.empty?

          {
            assertion_density: density,
            mutation_correlation: pearson(scores.map(&:first), scores.map(&:last)),
            mutation_samples: scores.length
          }
        end

        def precision(labels_payload)
          labels = labels_payload.fetch("labels", labels_payload)
          total = labels.length
          return { total: 0, precision: nil } if total.zero?

          false_positives = labels.count { |label| label.fetch("label", label[:label]) == "false_positive" }
          true_positives = total - false_positives
          {
            false_positives: false_positives,
            precision: true_positives.fdiv(total),
            total: total,
            true_positives: true_positives
          }
        end

        private

        def normalize_static(finding)
          hash = finding.respond_to?(:to_h) ? finding.to_h : finding
          { location: hash.fetch(:location, hash["location"]), rule: hash.fetch(:rule, hash["rule"]).to_s }
        end

        def normalize_dynamic(example)
          example.fetch("verdicts", []).map do |verdict|
            { location: example.fetch("location"), rule: verdict.fetch("rule").to_s }
          end
        end

        def percentile(sorted, quantile)
          sorted[((sorted.length - 1) * quantile).ceil]
        end

        def mutation_scores(dynamic_payload, mutation_payload)
          by_location = mutation_payload.fetch("examples", mutation_payload).to_h do |entry|
            [entry.fetch("location"), entry.fetch("mutation_score").to_f]
          end

          dynamic_payload.fetch("examples", []).filter_map do |example|
            score = by_location[example.fetch("location")]
            next unless score

            [
              example.fetch("expectation_count", 0) +
                example.fetch("mock_expectation_count", 0) +
                example.fetch("custom_expectation_count", 0),
              score
            ]
          end
        end

        def pearson(xs, ys)
          x_mean = xs.sum.fdiv(xs.length)
          y_mean = ys.sum.fdiv(ys.length)
          numerator = xs.zip(ys).sum { |x, y| (x - x_mean) * (y - y_mean) }
          x_denominator = Math.sqrt(xs.sum { |x| (x - x_mean)**2 })
          y_denominator = Math.sqrt(ys.sum { |y| (y - y_mean)**2 })
          return nil if x_denominator.zero? || y_denominator.zero?

          numerator / (x_denominator * y_denominator)
        end
      end
    end
  end
end
