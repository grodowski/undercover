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

    def uncovered_branches(result)
      annotated_branches(result)
        .reject { |b| result.skipped?(result.file_path, b[:line]) || b[:count] == 'ignored' }
        .select { |b| b[:count].zero? }
        .map { |b| b.except(:count) }
    end

    def annotated_branches(result) # rubocop:disable Metrics/AbcSize
      ast_info = AstBranchAnnotator.call(result.node.ast_node)
      counts_per_line = result.branches.each_with_object(Hash.new(0)) { |b, h| h[b[:line]] += 1 }
      result.branches.map do |entry|
        arm = result.branch_label(result.file_path, entry[:branch]) if counts_per_line[entry[:line]] > 1
        label = [ast_info[entry[:line]], arm].compact.join(' → ')
        next entry if label.empty?

        entry.merge(description: label)
      end
    end

    def summary
      {
        total_warnings: @results.size,
        files_affected: @results.map(&:file_path).uniq.size
      }
    end
  end
end
