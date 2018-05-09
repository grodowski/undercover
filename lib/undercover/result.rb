# frozen_string_literal: true

require 'forwardable'

module Undercover
  class Result
    extend Forwardable

    attr_reader :node, :coverage, :file_path

    def_delegators :node, :first_line, :last_line

    def initialize(node, file_cov, file_path)
      @node = node
      @coverage = file_cov.select do |ln, _|
        ln > first_line && ln < last_line
      end
      @file_path = file_path
    end

    # TODO: make DRY
    def non_code?(line_no)
      line_cov = coverage.find { |ln, _cov| ln == line_no }
      !line_cov
    end

    def covered?(line_no)
      line_cov = coverage.find { |ln, _cov| ln == line_no }
      line_cov && line_cov[1].positive?
    end

    def uncovered?(line_no)
      line_cov = coverage.find { |ln, _cov| ln == line_no }
      line_cov && line_cov[1].zero?
    end

    def coverage_f
      covered = coverage.reduce(0) do |sum, (_, cov)|
        sum + [[0, cov].max, 1].min
      end
      (covered.to_f / coverage.size).round(4)
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
        if line.strip.length.zero?
          Rainbow(formatted_line).darkgray.dark
        elsif covered.nil?
          Rainbow(formatted_line).darkgray.dark + \
            Rainbow(' hits: n/a').italic.darkgray.dark
        elsif covered.positive?
          Rainbow(formatted_line).green + \
            Rainbow(" hits: #{covered}").italic.darkgray.dark
        elsif covered.zero?
          Rainbow(formatted_line).red + \
            Rainbow(" hits: #{covered}").italic.darkgray.dark
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
  end
end
