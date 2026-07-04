# frozen_string_literal: true

require "ripper"

module RSpec
  module Risky
    class StaticDetector
      ASSERTION_METHODS = %w[assert expect refute].freeze
      OUTPUT_METHODS = %w[p print printf puts warn].freeze
      TEST_METHODS = %w[it scenario specify test].freeze

      Finding = Struct.new(:file, :line, :rule, :evidence, keyword_init: true) do
        def to_h
          {
            file: file,
            line: line,
            location: "#{file}:#{line}",
            rule: rule,
            evidence: evidence
          }
        end
      end

      def self.scan(paths)
        new(paths).scan
      end

      def initialize(paths)
        @paths = Array(paths).flat_map { |path| expand_path(path) }
      end

      def scan
        @paths.flat_map { |path| scan_file(path) }
      end

      private

      def expand_path(path)
        return Dir["#{path}/**/*_spec.rb", "#{path}/**/test_*.rb"] if File.directory?(path)

        path
      end

      def scan_file(path)
        ast = Ripper.sexp(File.read(path))
        return [] unless ast

        test_blocks(ast).flat_map { |block| findings_for(path, block) }
      end

      def test_blocks(node)
        return [] unless node.is_a?(Array)

        blocks = []
        blocks << test_block(node) if node.first == :method_add_block && test_declaration?(node[1])
        node.each { |child| blocks.concat(test_blocks(child)) if child.is_a?(Array) }
        blocks.compact
      end

      def test_block(node)
        { body: node[2], line: declaration_line(node[1]) }
      end

      def test_declaration?(node)
        TEST_METHODS.include?(method_name(node))
      end

      def method_name(node)
        return unless node.is_a?(Array)

        case node.first
        when :command
          token_text(node[1])
        when :method_add_arg
          method_name(node[1])
        when :fcall
          token_text(node[1])
        end
      end

      def declaration_line(node)
        token = declaration_token(node)
        token ? token[2].first : 1
      end

      def declaration_token(node)
        return unless node.is_a?(Array)
        return node[1] if %i[command fcall].include?(node.first)

        node.each do |child|
          token = declaration_token(child)
          return token if token
        end

        nil
      end

      def findings_for(path, block)
        findings = []
        findings << unknown_test(path, block) unless assertion?(block.fetch(:body))
        findings << redundant_print(path, block) if redundant_print?(block.fetch(:body))
        findings.compact
      end

      def assertion?(node)
        method_called?(node) do |name|
          ASSERTION_METHODS.include?(name) ||
            name == "should" ||
            name.start_with?("must_", "wont_", "will_")
        end
      end

      def redundant_print?(node)
        method_called?(node) { |name| OUTPUT_METHODS.include?(name) } && !output_matcher?(node)
      end

      def output_matcher?(node)
        method_called?(node) { |name| name == "output" }
      end

      def method_called?(node, &block)
        return false unless node.is_a?(Array)

        called_method = called_method_name(node)
        return true if called_method && block.call(called_method)

        node.any? { |child| child.is_a?(Array) && method_called?(child, &block) }
      end

      def called_method_name(node)
        case node.first
        when :command, :fcall
          token_text(node[1])
        when :command_call, :call
          token_text(node[3])
        when :method_add_arg
          called_method_name(node[1])
        end
      end

      def unknown_test(path, block)
        Finding.new(
          file: path,
          line: block.fetch(:line),
          rule: :unknown_test,
          evidence: { source: "static_ast", reason: "no assertion call found" }
        )
      end

      def redundant_print(path, block)
        Finding.new(
          file: path,
          line: block.fetch(:line),
          rule: :redundant_print,
          evidence: { source: "static_ast", reason: "print call found" }
        )
      end

      def token_text(token)
        return unless token.is_a?(Array)

        token[1].to_s
      end
    end
  end
end
