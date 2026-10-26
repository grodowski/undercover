# frozen_string_literal: true

require 'forwardable'

module Undercover
  class Result # rubocop:disable Metrics/ClassLength
    extend Forwardable

    attr_reader :node, :coverage, :coverage_adapter, :file_path

    def_delegators :node, :first_line, :last_line, :name
    def_delegators :coverage_adapter, :skipped?, :branch_label

    # @param coverage_index [CoverageIndex] the file's coverage, shared by all of its nodes
    def initialize(node, coverage_adapter, file_path, coverage_index: nil)
      @node = node
      @coverage_adapter = coverage_adapter
      coverage_index ||= CoverageIndex.new(coverage_adapter.coverage(file_path))
      @coverage = coverage_index.within(coverage_lines)

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
      return false if skipped?(file_path, line_no)
      return true if coverage.empty?
      return true if uncovered_branch_lines.include?(line_no)

      line_hits[line_no]&.zero?
    end

    # Method `coverage_f` returns the total coverage of this Undercover::Result
    # as a % value, taking into account missing branches. Line coverage will be counted
    # as 0 if any branch is untested.
    # rubocop:disable-next Metrics/AbcSize, Metrics/MethodLength
    def coverage_f
      return 0.0 if coverage.empty?

      lines = {}
      coverage.each do |ln, block_or_line_cov, _, branch_cov|
        if skipped?(file_path, ln)
          lines[ln] = 1
          next
        end

        lines[ln] = 1 unless lines.key?(ln)
        if branch_cov
          lines[ln] = 0 if branch_cov != 'ignored' && branch_cov.zero?
        elsif block_or_line_cov.zero?
          lines[ln] = 0
        end
      end

      (lines.values.sum.to_f / lines.keys.size).round(4)
    end

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
        if line.strip.empty?
          Rainbow(formatted_line).darkgray.dark
        elsif skipped?(file_path, num)
          Rainbow(formatted_line).darkgray.dark +
            Rainbow(' skipped').italic.darkgray.dark
        elsif covered.nil?
          Rainbow(formatted_line).darkgray.dark +
            Rainbow(' hits: n/a').italic.darkgray.dark +
            count_covered_branches(num)
        elsif covered.positive?
          Rainbow(formatted_line).green +
            Rainbow(" hits: #{covered}").italic.darkgray.dark +
            count_covered_branches(num)
        elsif covered.zero?
          Rainbow(formatted_line).red +
            Rainbow(" hits: #{covered}").italic.darkgray.dark +
            count_covered_branches(num)
        end
      end.join("\n")
    end
    # rubocop:enable Metrics/MethodLength, Metrics/AbcSize

    # Returns raw branch coverage entries for this result as structured hashes.
    # Callers that need human-readable descriptions should use AstBranchAnnotator
    # separately (e.g. JsonFormatter).
    def branches
      coverage.select { |cov| cov.size == 4 }.map do |ln, block_no, branch_no, count|
        {line: ln, block: block_no, branch: branch_no, count: count}
      end
    end

    def file_path_with_lines
      "#{file_path}:#{first_line}:#{last_line}"
    end

    def inspect
      "#<Undercover::Report::Result:#{object_id} " \
        "name: #{node.name}, coverage: #{coverage_f}>"
    end
    alias to_s inspect

    private

    def coverage_lines
      return first_line..first_line if first_line == last_line
      return first_line..last_line if covers_own_boundaries?

      (first_line + 1)..(last_line - 1)
    end

    def covers_own_boundaries?
      node.empty_def? || node.kind == :block || node.is_a?(ErbNode)
    end

    def uncovered_branch_lines
      @uncovered_branch_lines ||= coverage.filter_map do |ln, _block, _branch, cov|
        ln if cov && cov != 'ignored' && cov.zero?
      end.to_set
    end

    # first line tuple per line, as a linear search would find it
    def line_hits
      @line_hits ||= coverage.each_with_object({}) do |cov, hits|
        hits[cov[0]] = cov[1] if cov.size == 2 && !hits.key?(cov[0])
      end
    end

    def count_covered_branches(line_number) # rubocop:disable Metrics/MethodLength, Metrics/AbcSize
      branches = coverage.select { |cov| cov.size == 4 && cov[0] == line_number }
      count_covered = branches.count do |cov|
        branch_cov = cov[3]
        branch_cov == 'ignored' || (branch_cov.respond_to?(:positive?) && branch_cov.positive?)
      end

      return '' if branches.empty?

      if count_covered < branches.size
        Rainbow(' branches: ').italic.darkgray.dark +
          Rainbow("#{count_covered}/#{branches.size}").italic.red
      else
        Rainbow(" branches: #{count_covered}/#{branches.size}").italic.darkgray.dark
      end
    end
  end
end
