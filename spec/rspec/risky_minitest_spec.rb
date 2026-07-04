# frozen_string_literal: true

require "open3"
require "rbconfig"
require "tempfile"

RSpec.describe "risky minitest integration" do
  def run_isolated_minitest(source, *extra_args)
    Tempfile.create(["rspec-risky-minitest", "_test.rb"]) do |file|
      file.write(source)
      file.flush

      command = [
        RbConfig.ruby,
        "-I#{File.expand_path("../../lib", __dir__)}",
        file.path,
        *extra_args
      ]

      stdout, stderr, status = Open3.capture3(*command)
      return [status.exitstatus, stdout, stderr]
    end
  end

  it "provides a minitest plugin" do
    status, stdout, stderr = run_isolated_minitest(<<~RUBY)
      require "minitest/autorun"
      require "minitest/risky_plugin"

      class RiskyMinitestTest < Minitest::Test
        def test_no_assertions
          Object.new
        end
      end
    RUBY

    expect(status).to eq(0), stderr
    expect(stdout).to include("Risky tests:")
    expect(stdout).to include("unknown_test")
  end

  it "can fail minitest risky tests" do
    status, stdout, _stderr = run_isolated_minitest(<<~RUBY, "--risky-fail")
      require "minitest/autorun"
      require "minitest/risky_plugin"

      class StrictRiskyMinitestTest < Minitest::Test
        def test_no_assertions
          Object.new
        end
      end
    RUBY

    expect(status).to eq(1)
    expect(stdout).to include("no assertions were executed")
  end

  it "can allow Kernel.warn output in minitest" do
    status, stdout, stderr = run_isolated_minitest(<<~RUBY, "--risky-allow-warn")
      require "minitest/autorun"
      require "minitest/risky_plugin"

      class WarnRiskyMinitestTest < Minitest::Test
        def test_warns
          warn "allowed"
          assert true
        end
      end
    RUBY

    expect(status).to eq(0), stderr
    expect(stdout).not_to include("redundant_print")
  end
end
