# frozen_string_literal: true

require 'undercover/coverage_root'

module Undercover
  class SimplecovResultAdapter
    attr_reader :simplecov_result
    attr_accessor :coverage_root

    # @param file[File] JSON file supplied by SimpleCov::Formatter::Undercover
    # @return SimplecovResultAdapter
    def self.parse(file, opts = nil, only_files: nil)
      # :nocov:
      result_h = JSON.parse(file.read)
      raise ArgumentError, 'empty SimpleCov' if result_h.empty?

      new(result_h, opts, only_files: only_files)
      # :nocov:
    end

    # @param simplecov_result[SimpleCov::Result]
    def initialize(simplecov_result, _opts = nil, only_files: nil)
      @simplecov_result = simplecov_result
      @coverage_root = CoverageRoot::NONE
      return unless only_files

      # Derive before filtering: the prefix is read off the full key set.
      @coverage_root = CoverageRoot.derive(only_files, coverage_keys)
      wanted = only_files.to_set { |f| CoverageRoot.strip(f, coverage_root) }
      simplecov_result['coverage'].select! { |path, _| wanted.include?(path) }
    end

    # @return Array paths relative to SimpleCov.root
    def coverage_keys
      simplecov_result['coverage'].keys
    end

    # @param filepath[String]
    # @return Array tuples (lines) and quadruples (branches) compatible with LcovParser
    def coverage(filepath) # rubocop:disable Metrics/MethodLength
      source_file = find_file(filepath)

      return [] unless source_file

      lines = source_file['lines'].map.with_index do |line_coverage, idx|
        [idx + 1, line_coverage] if line_coverage
      end.compact
      return lines unless source_file['branches']

      branch_idx = 0
      branches = source_file['branches'].map do |branch|
        branch_idx += 1
        [branch['start_line'], 0, branch_idx, branch['coverage']]
      end
      lines + branches
    end

    def skipped?(filepath, line_no)
      source_file = find_file(filepath)
      return false unless source_file

      source_file['lines'][line_no - 1] == 'ignored'
    end

    def branch_label(filepath, branch_no)
      source_file = find_file(filepath)
      return nil unless source_file

      source_file['branches']&.dig(branch_no - 1, 'type')
    end

    # unused for now
    def total_coverage; end
    def total_branch_coverage; end

    def ignored_files
      @ignored_files ||= simplecov_result.dig('meta', 'ignored_files') || []
    end

    private

    def find_file(filepath)
      simplecov_result['coverage'][CoverageRoot.strip(filepath, coverage_root)]
    end
  end
end
