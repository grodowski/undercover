# frozen_string_literal: true

module Undercover
  class SimplecovResultAdapter
    attr_reader :simplecov_result

    # TODO: re-do and not rely on .resultset.json, but a properly formatted file
    # - needed: relative paths for portability (e.g. CI artifact file from a build _somewhere_)
    # - no reliance on SimpleCov internals changing (github issue)
    # @param file[File] .resultset.json file supplied by SimpleCov
    # @return SimplecovResultAdapter
    def self.parse(file)
      # :nocov:
      result_h = JSON.parse(file.read)
      raise ArgumentError, 'empty SimpleCov' if result_h.empty?
      raise ArgumentError, "too many test suites in resultset: got #{result_h.size}, expected 1" if result_h.size > 1

      new(SimpleCov::Result.from_hash(result_h).first)
      # :nocov:
    end

    # @param simplecov_result[SimpleCov::Result]
    def initialize(simplecov_result)
      @simplecov_result = simplecov_result
    end

    # @param filepath[String]
    # @return Array tuples (lines) and quadruples (branches) compatible with LcovParser
    def coverage(filepath) # rubocop:disable Metrics/MethodLength
      source_file = find_file(filepath)

      return [] unless source_file

      lines = source_file.lines.map do |line|
        [line.line_number, line.coverage] if line.coverage
      end.compact
      branch_idx = 0
      branches = source_file.branches.map do |branch|
        branch_idx += 1
        [branch.report_line, 0, branch_idx, branch.coverage]
      end
      lines + branches
    end

    def skipped?(filepath, line_no)
      source_file = find_file(filepath)
      return false unless source_file

      source_file.skipped_lines.map(&:number).include?(line_no)
    end

    # TODO: unimplemented and unused for now
    def total_coverage; end
    def total_branch_coverage; end

    private

    def find_file(filepath)
      # TODO: dirty, configure SimpleCov.root from --project-path?
      simplecov_result.files.find { _1.filename.end_with? filepath }
    end
  end
end
