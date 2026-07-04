# frozen_string_literal: true

require "json"
require "rake"

require_relative "evaluation"
require_relative "static_detector"

namespace :risky do
  desc "Run the evaluation static detector. Usage: rake risky:static[spec]"
  task :static, [:paths] do |_task, args|
    paths = args[:paths]&.split(",") || ["spec", "test"]
    findings = RSpec::Risky::StaticDetector.scan(paths.select { |path| File.exist?(path) })
    puts JSON.pretty_generate(findings: findings.map(&:to_h))
  end

  desc "Compare static findings and runtime JSON. Usage: rake risky:compare[static.json,dynamic.json]"
  task :compare, [:static_json, :dynamic_json] do |_task, args|
    abort "static_json is required" unless args[:static_json]
    abort "dynamic_json is required" unless args[:dynamic_json]

    static_payload = JSON.parse(File.read(args[:static_json]))
    dynamic_payload = JSON.parse(File.read(args[:dynamic_json]))
    comparison = RSpec::Risky::Evaluation.compare(
      static_findings: static_payload.fetch("findings"),
      dynamic_payload: dynamic_payload
    )
    puts JSON.pretty_generate(comparison)
  end

  desc "Report assertion density and optional mutation correlation. Usage: rake risky:study[dynamic.json,mutation.json]"
  task :study, [:dynamic_json, :mutation_json] do |_task, args|
    abort "dynamic_json is required" unless args[:dynamic_json]

    payload = JSON.parse(File.read(args[:dynamic_json]))
    mutation_payload = JSON.parse(File.read(args[:mutation_json])) if args[:mutation_json]
    puts JSON.pretty_generate(RSpec::Risky::Evaluation.mutation_study(payload, mutation_payload))
  end

  desc "Create a precision labeling template. Usage: rake risky:label[dynamic.json]"
  task :label, [:dynamic_json] do |_task, args|
    abort "dynamic_json is required" unless args[:dynamic_json]

    payload = JSON.parse(File.read(args[:dynamic_json]))
    puts JSON.pretty_generate(labels: RSpec::Risky::Evaluation.label_template(payload))
  end

  desc "Calculate precision from labels. Usage: rake risky:precision[labels.json]"
  task :precision, [:labels_json] do |_task, args|
    abort "labels_json is required" unless args[:labels_json]

    payload = JSON.parse(File.read(args[:labels_json]))
    puts JSON.pretty_generate(RSpec::Risky::Evaluation.precision(payload))
  end
end
