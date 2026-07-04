# frozen_string_literal: true

require "json"
require "open3"
require "rbconfig"
require "tempfile"

RSpec.describe "completed risky features" do
  def run_command(*command)
    stdout, stderr, status = Open3.capture3(*command)
    [status.exitstatus, stdout, stderr]
  end
  def run_isolated_rspec(source, *extra_args, formatter: "RSpec::Risky::Formatter")
    Tempfile.create(["rspec-risky", "_spec.rb"]) do |file|
      file.write(source)
      file.flush

      command = [
        RbConfig.ruby,
        "-I#{File.expand_path("../../lib", __dir__)}",
        "-rrspec/risky/autorun",
        Gem.bin_path("rspec-core", "rspec"),
        "--format",
        formatter,
        "--no-color",
        *extra_args,
        file.path
      ]

      run_command(*command)
    end
  end

  it "supports --risky-exit-code without failing examples" do
    status, stdout, stderr = run_isolated_rspec(<<~RUBY, "--risky-exit-code", "7")
      RSpec.describe "risky exit code" do
        it "does not assert" do
          Object.new
        end
      end
    RUBY

    expect(status).to eq(7), stderr
    expect(stdout).to include("unknown_test")
  end

  it "supports --risky-exit-code through the rspec-risky wrapper" do
    Tempfile.create(["rspec-risky-wrapper", "_spec.rb"]) do |file|
      file.write(<<~RUBY)
        RSpec.describe "wrapper" do
          it "does not assert" do
            Object.new
          end
        end
      RUBY
      file.flush

      status, stdout, stderr = run_command(
        RbConfig.ruby,
        "-I#{File.expand_path("../../lib", __dir__)}",
        File.expand_path("../../exe/rspec-risky", __dir__),
        "--risky-exit-code",
        "7",
        "--format",
        "RSpec::Risky::Formatter",
        "--no-color",
        file.path
      )

      expect(status).to eq(7), stderr
      expect(stdout).to include("unknown_test")
    end
  end

  it "supports custom expectation recording" do
    status, stdout, stderr = run_isolated_rspec(<<~RUBY)
      RSpec.describe "custom adapter" do
        it "asserts externally" do
          RSpec::Risky.record_expectation
        end
      end
    RUBY

    expect(status).to eq(0), stderr
    expect(stdout).not_to include("unknown_test")
  end

  it "supports callable custom expectation adapters" do
    status, stdout, stderr = run_isolated_rspec(<<~RUBY)
      RSpec::Risky.configure(RSpec.configuration) do |risky|
        risky.unknown_test.adapters << ->(_example) { 1 }
      end

      RSpec.describe "callable adapter" do
        it "asserts externally" do
          Object.new
        end
      end
    RUBY

    expect(status).to eq(0), stderr
    expect(stdout).not_to include("unknown_test")
  end

  it "captures fd-level stdout in strict mode" do
    status, stdout, stderr = run_isolated_rspec(<<~RUBY)
      RSpec::Risky.configure(RSpec.configuration) do |risky|
        risky.redundant_print.strict = true
      end

      RSpec.describe "strict output" do
        it "writes to STDOUT" do
          STDOUT.write("fd output\\\\n")
          expect(true).to eq(true)
        end
      end
    RUBY

    expect(status).to eq(0), stderr
    expect(stdout).to include("redundant_print")
    expect(stdout).to include("fd output")
  end

  it "can capture logger output when opted in" do
    status, stdout, stderr = run_isolated_rspec(<<~RUBY)
      require "logger"

      RSpec::Risky.configure(RSpec.configuration) do |risky|
        risky.redundant_print.capture_loggers = true
      end

      RSpec.describe "logger output" do
        it "logs" do
          Logger.new($stderr).warn("logged")
          expect(true).to eq(true)
        end
      end
    RUBY

    expect(status).to eq(0), stderr
    expect(stdout).to include("redundant_print")
    expect(stdout).to include("logger")
  end

  it "emits newline-delimited JSON events" do
    status, stdout, stderr = run_isolated_rspec(<<~RUBY, formatter: "RSpec::Risky::JsonEventFormatter")
      RSpec.describe "event output" do
        it "does not assert" do
          Object.new
        end
      end
    RUBY

    payload = JSON.parse(stdout.lines.first)

    expect(status).to eq(0), stderr
    expect(payload.fetch("event")).to eq("rspec_risky.verdict")
    expect(payload.dig("verdict", "rule")).to eq("unknown_test")
  end

end
