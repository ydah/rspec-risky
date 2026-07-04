# frozen_string_literal: true

require "json"
require "open3"
require "tempfile"

RSpec.describe "risky evaluation tasks" do
  def run_command(*command)
    stdout, stderr, status = Open3.capture3(*command)
    [status.exitstatus, stdout, stderr]
  end

  it "runs the AST static detector through rake" do
    Tempfile.create(["rspec-risky-static", "_spec.rb"]) do |file|
      file.write(<<~RUBY)
        RSpec.describe "static" do
          it "does not assert" do
            Object.new
          end
        end
      RUBY
      file.flush

      status, stdout, stderr = run_command("bundle", "exec", "rake", "risky:static[#{file.path}]")
      payload = JSON.parse(stdout)

      expect(status).to eq(0), stderr
      expect(payload.fetch("findings").first.fetch("rule")).to eq("unknown_test")
    end
  end

  it "does not treat assertion words in descriptions as static assertions" do
    Tempfile.create(["rspec-risky-static-description", "_spec.rb"]) do |file|
      file.write(<<~RUBY)
        RSpec.describe "static" do
          it "does not assert" do
            Object.new
          end
        end
      RUBY
      file.flush

      status, stdout, stderr = run_command("bundle", "exec", "rake", "risky:static[#{file.path}]")
      payload = JSON.parse(stdout)

      expect(status).to eq(0), stderr
      expect(payload.fetch("findings").length).to eq(1)
      expect(payload.fetch("findings").first.fetch("evidence").fetch("source")).to eq("static_ast")
    end
  end

  it "generates precision labels and calculates precision" do
    Tempfile.create(["rspec-risky-dynamic", ".json"]) do |dynamic_file|
      dynamic_file.write(JSON.pretty_generate(
        examples: [
          {
            location: "spec/a_spec.rb:1",
            description: "a",
            expectation_count: 0,
            mock_expectation_count: 0,
            custom_expectation_count: 0,
            verdicts: [{ rule: "unknown_test" }]
          }
        ]
      ))
      dynamic_file.flush

      status, stdout, stderr = run_command("bundle", "exec", "rake", "risky:label[#{dynamic_file.path}]")
      labels = JSON.parse(stdout).fetch("labels")
      expect(status).to eq(0), stderr
      expect(labels.first.fetch("allowed_labels")).to include("false_positive")

      Tempfile.create(["rspec-risky-labels", ".json"]) do |labels_file|
        labels.first["label"] = "true_missing_oracle"
        labels_file.write(JSON.pretty_generate(labels: labels))
        labels_file.flush

        status, stdout, stderr = run_command("bundle", "exec", "rake", "risky:precision[#{labels_file.path}]")
        payload = JSON.parse(stdout)

        expect(status).to eq(0), stderr
        expect(payload.fetch("precision")).to eq(1.0)
      end
    end
  end

  it "combines assertion density with mutation scores" do
    Tempfile.create(["rspec-risky-dynamic", ".json"]) do |dynamic_file|
      dynamic_file.write(JSON.pretty_generate(
        examples: [
          {
            location: "spec/a_spec.rb:1",
            expectation_count: 1,
            mock_expectation_count: 0,
            custom_expectation_count: 0,
            verdicts: []
          },
          {
            location: "spec/b_spec.rb:1",
            expectation_count: 3,
            mock_expectation_count: 0,
            custom_expectation_count: 0,
            verdicts: []
          }
        ]
      ))
      dynamic_file.flush

      Tempfile.create(["rspec-risky-mutation", ".json"]) do |mutation_file|
        mutation_file.write(JSON.pretty_generate(
          examples: [
            { location: "spec/a_spec.rb:1", mutation_score: 0.25 },
            { location: "spec/b_spec.rb:1", mutation_score: 0.75 }
          ]
        ))
        mutation_file.flush

        status, stdout, stderr = run_command(
          "bundle",
          "exec",
          "rake",
          "risky:study[#{dynamic_file.path},#{mutation_file.path}]"
        )
        payload = JSON.parse(stdout)

        expect(status).to eq(0), stderr
        expect(payload.fetch("mutation_samples")).to eq(2)
        expect(payload.fetch("mutation_correlation")).to be_within(0.000001).of(1.0)
      end
    end
  end
end
