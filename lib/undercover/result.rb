# frozen_string_literal: true

require 'forwardable'

module Undercover
  class Result
    extend Forwardable

    attr_reader :node, :coverage, :file_path

    def_delegators :node, :first_line, :last_line, :name

    def initialize(node, file_cov, file_path)
      @node = node
      @coverage = file_cov.select do |ln, _|
        ln > first_line && ln < last_line
      end
      @file_path = file_path
      @flagged = false
    end

    def flag
      @flagged = true
    end

    def flagged?
      @flagged
    end

    def uncovered?(line_no)
      # check branch coverage for line_no
      coverage.each do |ln, _block, _branch, cov|
        return true if ln == line_no && cov && cov.zero?
      end

      # check line coverage for line_no
      line_cov = coverage.select { |cov| cov.size == 2 }.find { |ln, _cov| ln == line_no }
      line_cov && line_cov[1].zero?
    end

    # Method `coverage_f` returns the total coverage of this Undercover::Result
    # as a % value, taking into account missing branches. Line coverage will be counted
    # as 0 if any branch is untested.
    # rubocop:disable Metrics/AbcSize, Metrics/MethodLength
    def coverage_f
      lines = {}
      coverage.each do |ln, block_or_line_cov, _, branch_cov|
        lines[ln] = 1 unless lines.key?(ln)
        if branch_cov
          lines[ln] = 0 if branch_cov.zero?
        elsif block_or_line_cov.zero?
          lines[ln] = 0
        end
      end
      return 1.0 if lines.keys.size.zero?

      (lines.values.sum.to_f / lines.keys.size).round(4)
    end
    # rubocop:enable Metrics/AbcSize, Metrics/MethodLength

    # TODO: create a formatter interface instead and add some tests.
    # TODO: re-enable rubocops
    # rubocop:disable Metrics/MethodLength, Metrics/AbcSize
    #
    # Zips coverage data (that doesn't include any non-code lines) with
    # full source for given code fragment (this includes non-code lines!)
    def pretty_print_lines
      cov_enum = coverage.each
      cov_source_lines = (node.first_line..node.last_line).map do |line_no|
        cov_line_no = begin
          cov_enum.peek[0]
        rescue StopIteration
          -1
        end
        cov_enum.next[1] if cov_line_no == line_no
      end
      cov_source_lines.zip(node.source_lines_with_numbers)
    end

    # TODO: move to formatter interface instead!
    def pretty_print
      pad = node.last_line.to_s.length
      pretty_print_lines.map do |covered, (num, line)|
        formatted_line = "#{num.to_s.rjust(pad)}: #{line}"
        if line.strip.length.zero?
          Rainbow(formatted_line).darkgray.dark
        elsif covered.nil?
          Rainbow(formatted_line).darkgray.dark + \
            Rainbow(' hits: n/a').italic.darkgray.dark
        elsif covered.positive?
          Rainbow(formatted_line).green + \
            Rainbow(" hits: #{covered}").italic.darkgray.dark + \
            count_covered_branches(num)
        elsif covered.zero?
          Rainbow(formatted_line).red + \
            Rainbow(" hits: #{covered}").italic.darkgray.dark + \
            count_covered_branches(num)
        end
      end.join("\n")
    end
    # rubocop:enable Metrics/MethodLength, Metrics/AbcSize

    def file_path_with_lines
      "#{file_path}:#{first_line}:#{last_line}"
    end

    def inspect
      "#<Undercover::Report::Result:#{object_id}" \
        " name: #{node.name}, coverage: #{coverage_f}>"
    end
    alias to_s inspect

    private

    # rubocop:disable Metrics/AbcSize
    def count_covered_branches(line_number)
      branches = coverage.select { |cov| cov.size == 4 && cov[0] == line_number }
      count_covered = branches.count { |cov| cov[3].positive? }

      return '' if branches.size.zero?

      if count_covered < branches.size
        Rainbow(' branches: ').italic.darkgray.dark + \
          Rainbow("#{count_covered}/#{branches.size}").italic.red
      else
        Rainbow(" branches: #{count_covered}/#{branches.size}").italic.darkgray.dark
      end
    end
    # rubocop:enable Metrics/AbcSize
  end
end
