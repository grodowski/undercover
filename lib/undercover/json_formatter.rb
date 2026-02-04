# frozen_string_literal: true

require 'json'

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
          uncovered_lines: uncovered_lines(result)
        }
      end
    end

    def uncovered_lines(result)
      (result.first_line..result.last_line).select do |line_no|
        result.uncovered?(line_no)
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
