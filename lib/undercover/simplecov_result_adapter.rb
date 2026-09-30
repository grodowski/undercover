# frozen_string_literal: true

require 'undercover/coverage_root'

module Undercover
  class SimplecovResultAdapter
    attr_reader :simplecov_result, :only_files, :coverage_root

    # @param file[File] JSON file supplied by SimpleCov::Formatter::Undercover
    # @return SimplecovResultAdapter
    def self.parse(file, opts = nil, only_files: nil)
      # simplecov:disable
      result_h = JSON.parse(file.read)
      raise ArgumentError, 'empty SimpleCov' if result_h.empty?

      new(result_h, opts, only_files: only_files)
      # simplecov:enable
    end

    # @param simplecov_result[SimpleCov::Result]
    def initialize(simplecov_result, _opts = nil, only_files: nil)
      @simplecov_result = simplecov_result
      @only_files = only_files
      @coverage_root = CoverageRoot::NONE
    end

    # Filtering waits for the coverage root, since only_files is relative to the repository
    # while coverage keys are relative to SimpleCov.root.
    def coverage_root=(root)
      @coverage_root = root || CoverageRoot::NONE
      keep_only_files!
    end

    # @return String SimpleCov.root as recorded when the report was written, an absolute
    #   path on the machine that ran the tests
    def simplecov_root
      simplecov_result.dig('meta', 'simplecov_root')
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

    def keep_only_files!
      return unless only_files

      wanted = only_files.to_set { |path| CoverageRoot.strip(path, coverage_root) }
      simplecov_result['coverage'].select! { |path, _| wanted.include?(path) }
    end

    def find_file(filepath)
      simplecov_result['coverage'][CoverageRoot.strip(filepath, coverage_root)]
    end
  end
end
