# rspec-risky

[![Ruby](https://github.com/ydah/rspec-risky/actions/workflows/main.yml/badge.svg)](https://github.com/ydah/rspec-risky/actions/workflows/main.yml)
[![Gem Version](https://img.shields.io/gem/v/rspec-risky.svg)](https://rubygems.org/gems/rspec-risky)

Runtime risky-test detection for RSpec.

`rspec-risky` reports examples that pass without executing any expectations, and examples that write unexpected output to `$stdout` or `$stderr`.

## Installation

Add the gem to your Gemfile:

```ruby
gem "rspec-risky"
```

Then require and configure it from your spec helper:

```ruby
require "rspec/risky"

RSpec.configure do |config|
  RSpec::Risky.configure(config) do |risky|
    risky.rules = %i[unknown_test redundant_print]
    risky.unknown_test.severity = :risky
    risky.unknown_test.count_mocks = true
    risky.unknown_test.adapters << ->(_example) { 0 }
    risky.redundant_print.severity = :risky
    risky.redundant_print.capture = :both
    risky.redundant_print.allow_warn = false
    risky.redundant_print.strict = false
    risky.redundant_print.capture_loggers = false
  end
end
```

You can also require `rspec/risky/autorun` to install the default configuration.

Use the formatter when you want risky examples to appear as `R` in progress output:

```sh
bundle exec rspec --require rspec/risky/autorun --format RSpec::Risky::Formatter
```

To use `--risky-exit-code`, use the wrapper executable or preload the gem before RSpec parses options:

```sh
ruby -S rspec-risky --risky-exit-code 7 --format RSpec::Risky::Formatter
ruby -rrspec/risky/autorun -S rspec --risky-exit-code 7 --format RSpec::Risky::Formatter
```

Use `RSpec::Risky::JsonFormatter` to emit machine-readable verdicts:

```sh
bundle exec rspec --require rspec/risky/autorun --format RSpec::Risky::JsonFormatter
```

Use `RSpec::Risky::JsonEventFormatter` to emit newline-delimited verdict events:

```sh
bundle exec rspec --require rspec/risky/autorun --format RSpec::Risky::JsonEventFormatter
```

Intentional smoke tests can opt out per example:

```ruby
it "boots", risky: { allow: [:unknown_test] } do
  App.boot!
end
```

Output that is explicitly asserted with RSpec's `output` matcher is not reported:

```ruby
it { expect { task.run }.to output(/done/).to_stdout }
```

Custom expectation libraries can call `RSpec::Risky.record_expectation` when they run a check.

## Minitest

Require the plugin from a Minitest suite:

```ruby
require "minitest/autorun"
require "minitest/risky_plugin"
```

Use `--risky-fail` to fail the process for risky Minitest results. Use `--risky-allow-warn` to ignore `Kernel#warn` output.

## Evaluation Tasks

The gem includes local evaluation helpers:

```sh
bundle exec rake risky:static[spec]
bundle exec rake risky:compare[static.json,dynamic.json]
bundle exec rake risky:label[dynamic.json]
bundle exec rake risky:precision[labels.json]
bundle exec rake risky:study[dynamic.json,mutation.json]
```

## License

The gem is available as open source under the terms of the [MIT License](https://opensource.org/licenses/MIT).
