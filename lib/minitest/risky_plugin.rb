# frozen_string_literal: true

require "minitest"
require "rspec/risky/minitest/plugin"

module Minitest
  register_plugin :risky

  def self.plugin_risky_options(opts, options)
    options[:risky] = {
      allow_warn: false,
      fail: false,
      redundant_print: true,
      unknown_test: true
    }

    opts.on("--risky-fail", "Fail the run when risky tests are detected.") do
      options[:risky][:fail] = true
    end

    opts.on("--risky-no-output", "Disable stdout/stderr risky detection.") do
      options[:risky][:redundant_print] = false
    end

    opts.on("--risky-allow-warn", "Do not flag Kernel#warn output.") do
      options[:risky][:allow_warn] = true
    end
  end

  def self.plugin_risky_init(options)
    RSpec::Risky::Minitest::Plugin.install(options.fetch(:risky))
  end
end
