# frozen_string_literal: true

require "json"
require "open3"
require "rbconfig"
require "tempfile"

RSpec.describe RSpec::Risky do
  def run_isolated_rspec(source, formatter: "RSpec::Risky::Formatter")
    Tempfile.create(["rspec-risky", "_spec.rb"]) do |file|
      file.write(source)
      file.flush

      command = [
        RbConfig.ruby,
        "-I#{File.expand_path("../../lib", __dir__)}",
        Gem.bin_path("rspec-core", "rspec"),
        "--require",
        "rspec/risky/autorun",
        "--format",
        formatter,
        "--no-color",
        file.path
      ]

      stdout, stderr, status = Open3.capture3(*command)
      return [status.exitstatus, stdout, stderr]
    end
  end

  it "has a version number" do
    expect(described_class::VERSION).not_to be_nil
  end

  it "reports an example with no expectations as risky" do
    status, stdout, stderr = run_isolated_rspec(<<~RUBY)
      RSpec.describe "unknown test" do
        it "does not assert" do
          1 + 1
        end
      end
    RUBY

    expect(status).to eq(0), stderr
    expect(stdout).to include("R")
    expect(stdout).to include("unknown_test")
  end

  it "emits JSON verdicts" do
    status, stdout, stderr = run_isolated_rspec(<<~RUBY, formatter: "RSpec::Risky::JsonFormatter")
      RSpec.describe "json output" do
        it "does not assert" do
          1 + 1
        end
      end
    RUBY

    payload = JSON.parse(stdout)

    expect(status).to eq(0), stderr
    expect(payload.dig("summary", "risky_count")).to eq(1)
    expect(payload.dig("examples", 0, "verdicts", 0, "rule")).to eq("unknown_test")
  end

  it "does not report examples that run expectations" do
    status, stdout, stderr = run_isolated_rspec(<<~RUBY)
      RSpec.describe "asserting test" do
        it "asserts" do
          expect(1 + 1).to eq(2)
        end
      end
    RUBY

    expect(status).to eq(0), stderr
    expect(stdout).not_to include("unknown_test")
    expect(stdout).not_to include("redundant_print")
  end

  it "counts RSpec mock expectations when configured to do so" do
    status, stdout, stderr = run_isolated_rspec(<<~RUBY)
      RSpec.describe "mock test" do
        it "verifies a message" do
          object = double("worker")
          expect(object).to receive(:call)
          object.call
        end
      end
    RUBY

    expect(status).to eq(0), stderr
    expect(stdout).not_to include("unknown_test")
  end

  it "reports unexpected stdout output" do
    status, stdout, stderr = run_isolated_rspec(<<~RUBY)
      RSpec.describe "printing test" do
        it "prints" do
          puts "syncing"
          expect(true).to eq(true)
        end
      end
    RUBY

    expect(status).to eq(0), stderr
    expect(stdout).to include("redundant_print")
    expect(stdout).to include("stdout 1 writes")
    expect(stdout).to include("syncing")
  end

  it "does not report output asserted with the output matcher" do
    status, stdout, stderr = run_isolated_rspec(<<~RUBY)
      RSpec.describe "output matcher" do
        it "asserts output" do
          expect { puts "done" }.to output("done\\n").to_stdout
        end
      end
    RUBY

    expect(status).to eq(0), stderr
    expect(stdout).not_to include("redundant_print")
  end

  it "does not report output asserted with the fd-level output matcher" do
    status, stdout, stderr = run_isolated_rspec(<<~RUBY)
      RSpec.describe "fd output matcher" do
        it "asserts output" do
          expect { puts "done" }.to output("done\\n").to_stdout_from_any_process
        end
      end
    RUBY

    expect(status).to eq(0), stderr
    expect(stdout).not_to include("redundant_print")
  end

  it "can allow Kernel.warn output" do
    status, stdout, stderr = run_isolated_rspec(<<~RUBY)
      RSpec::Risky.configure(RSpec.configuration) do |risky|
        risky.redundant_print.allow_warn = true
      end

      RSpec.describe "warn output" do
        it "warns intentionally" do
          warn "allowed"
          expect(true).to eq(true)
        end
      end
    RUBY

    expect(status).to eq(0), stderr
    expect(stdout).not_to include("redundant_print")
  end

  it "allows individual risky rules per example" do
    status, stdout, stderr = run_isolated_rspec(<<~RUBY)
      RSpec.describe "allowed smoke test" do
        it "boots", risky: { allow: [:unknown_test] } do
          Object.new
        end
      end
    RUBY

    expect(status).to eq(0), stderr
    expect(stdout).not_to include("unknown_test")
  end

  it "can fail examples for risky rules" do
    status, stdout, _stderr = run_isolated_rspec(<<~RUBY)
      RSpec::Risky.configure(RSpec.configuration) do |risky|
        risky.unknown_test.severity = :fail
      end

      RSpec.describe "strict unknown test" do
        it "does not assert" do
          Object.new
        end
      end
    RUBY

    expect(status).to eq(1)
    expect(stdout).to include("RISKY (unknown_test)")
  end
end
