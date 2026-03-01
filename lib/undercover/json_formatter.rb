# frozen_string_literal: true

require 'json'
require 'undercover/ast_branch_annotator'

module Undercover
  class JsonFormatter
    def initialize(results, validation_error = nil)
      @results = results
      @validation_error = validation_error
    end

    def to_s
      JSON.pretty_generate(to_h)
    end

    def to_h
      output = {
        warnings: warnings,
        summary: summary
      }
      output[:validation] = @validation_error.to_s if @validation_error && @validation_error != :no_changes
      output
    end

    def exit_code
      return 0 if @validation_error
      return 0 unless @results.any?

      1
    end

    private

    def warnings # rubocop:disable Metrics/MethodLength
      @results.map do |result|
        {
          node: result.node.name,
          type: result.node.human_name,
          file: result.file_path,
          first_line: result.first_line,
          last_line: result.last_line,
          coverage: result.coverage_f,
          uncovered_lines: uncovered_lines(result),
          uncovered_branches: uncovered_branches(result)
        }
      end
    end

    def uncovered_lines(result)
      result.coverage
            .select { |cov| cov.size == 2 }
            .reject { |ln, _| result.skipped?(result.file_path, ln) }
            .select { |_, count| count.zero? }
            .map { |ln, _| ln }
    end

    def uncovered_branches(result) # rubocop:disable Metrics/MethodLength,Metrics/AbcSize
      ast_info = AstBranchAnnotator.call(result.node.ast_node)
      branch_counts = branch_counts_per_line(result)

      result.coverage
            .select { |cov| cov.size == 4 }
            .reject { |ln, _, _, cov| result.skipped?(result.file_path, ln) || cov == 'ignored' }
            .select { |_, _, _, cov| cov.zero? }
            .map do |ln, block_no, branch_no, _|
              arm = result.branch_label(result.file_path, branch_no) if branch_counts[ln] > 1
              label = [ast_info[ln], arm].compact.join(' → ')
              entry = {line: ln, block: block_no, branch: branch_no}
              entry[:description] = label unless label.empty?
              entry
            end
    end

    def branch_counts_per_line(result)
      result.coverage
            .select { |cov| cov.size == 4 }
            .each_with_object(Hash.new(0)) { |(ln, *), counts| counts[ln] += 1 }
    end

    def summary
      {
        total_warnings: @results.size,
        files_affected: @results.map(&:file_path).uniq.size
      }
    end
  end
end
