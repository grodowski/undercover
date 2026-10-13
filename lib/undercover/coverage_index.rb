# frozen_string_literal: true

module Undercover
  # A file's coverage tuples indexed by line number, so each node reads only its own
  # lines instead of the whole file's coverage.
  class CoverageIndex
    def initialize(file_coverage)
      @file_coverage = file_coverage
      @positions = {}
      file_coverage.each_with_index { |(line_no, *), idx| (@positions[line_no] ||= []) << idx }
    end

    # @param lines [Range]
    # @return Array tuples on the given lines, in the order of the coverage report
    def within(lines)
      lines.flat_map { @positions[_1] || [] }.sort.map { @file_coverage[_1] }
    end
  end
end
