# frozen_string_literal: true

require "rspec/expectations"
require "rspec/mocks"

module RSpec
  module Risky
    module Probe
      module ExpectationProbe
        THREAD_KEY = :__rspec_risky_expectation_probe_state

        State = Struct.new(
          :example,
          :expectation_count,
          :mock_expectation_count,
          :custom_expectation_count,
          :previous_state,
          keyword_init: true
        )

        module StandardExpectationPatch
          def to(matcher = nil, message = nil, &block)
            ExpectationProbe.record_expectation if matcher
            super
          end

          def not_to(matcher = nil, message = nil, &block)
            ExpectationProbe.record_expectation if matcher
            super
          end

          def to_not(matcher = nil, message = nil, &block)
            ExpectationProbe.record_expectation if matcher
            super
          end
        end

        module ReceivePatch
          def setup_expectation(*args, &block)
            super.tap { ExpectationProbe.record_declared_mock_expectation }
          end

          def setup_negative_expectation(*args, &block)
            super.tap { ExpectationProbe.record_declared_mock_expectation }
          end

          def setup_any_instance_expectation(*args, &block)
            super.tap { ExpectationProbe.record_declared_mock_expectation }
          end

          def setup_any_instance_negative_expectation(*args, &block)
            super.tap { ExpectationProbe.record_declared_mock_expectation }
          end
        end

        module ReceiveMessagesPatch
          def setup_expectation(*args, &block)
            super.tap { ExpectationProbe.record_declared_mock_expectation(message_count) }
          end

          def setup_any_instance_expectation(*args, &block)
            super.tap { ExpectationProbe.record_declared_mock_expectation(message_count) }
          end

          private

          def message_count
            @message_return_value_hash.size
          end
        end

        module ReceiveMessageChainPatch
          def setup_expectation(*args, &block)
            super.tap { ExpectationProbe.record_declared_mock_expectation }
          end

          def setup_any_instance_expectation(*args, &block)
            super.tap { ExpectationProbe.record_declared_mock_expectation }
          end
        end

        module HaveReceivedPatch
          def matches?(*args, &block)
            ExpectationProbe.record_declared_mock_expectation
            super
          end

          def does_not_match?(*args, &block)
            ExpectationProbe.record_declared_mock_expectation
            super
          end
        end

        module ShouldSyntaxPatch
          def expect_message(*args, &block)
            super.tap { ExpectationProbe.record_declared_mock_expectation }
          end
        end

        class << self
          def install
            return if @installed

            ::RSpec::Expectations::ExpectationTarget.prepend(StandardExpectationPatch)
            ::RSpec::Mocks::Matchers::Receive.prepend(ReceivePatch)
            ::RSpec::Mocks::Matchers::ReceiveMessages.prepend(ReceiveMessagesPatch)
            ::RSpec::Mocks::Matchers::ReceiveMessageChain.prepend(ReceiveMessageChainPatch)
            ::RSpec::Mocks::Matchers::HaveReceived.prepend(HaveReceivedPatch)
            ::RSpec::Mocks.singleton_class.prepend(ShouldSyntaxPatch)

            @installed = true
          end

          def start(example)
            State.new(
              example: example,
              expectation_count: 0,
              mock_expectation_count: 0,
              custom_expectation_count: 0,
              previous_state: current
            ).tap { |state| Thread.current[THREAD_KEY] = state }
          end

          def finish(state)
            state.mock_expectation_count = [state.mock_expectation_count, verified_mock_expectation_count].max if state
            Thread.current[THREAD_KEY] = state.previous_state if state
            state
          end

          def record_expectation(count = 1)
            return unless current

            current.expectation_count += count
          end

          def record_mock_expectation(count = 1)
            return unless current

            current.mock_expectation_count += count
          end

          alias record_declared_mock_expectation record_mock_expectation

          def record_custom_expectation(count = 1)
            return unless current

            current.custom_expectation_count += count
          end

          private

          def current
            Thread.current[THREAD_KEY]
          end

          def verified_mock_expectation_count
            mock_proxy_expectations.count { |expectation| expectation.expected_messages_received? }
          rescue StandardError
            0
          end

          def mock_proxy_expectations
            space = ::RSpec::Mocks.space
            proxies = space.respond_to?(:proxies) ? space.proxies.values : []
            proxies.flat_map do |proxy|
              method_doubles = proxy.instance_variable_get(:@method_doubles)
              next [] unless method_doubles

              method_doubles.values.flat_map { |method_double| method_double.expectations }
            end
          end
        end
      end
    end
  end
end
