# frozen_string_literal: true

class SimplecovResultAdapter
  attr_reader :simplecov_result

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

  private

  def find_file(filepath)
    # TODO: dirty, configure SimpleCov.root from --project-path?
    simplecov_result.files.find { _1.filename.end_with? filepath }
  end
end
