# frozen_string_literal: true

$LOAD_PATH << 'lib'
require 'json'
require 'rainbow'
require 'forwardable'
require 'simplecov'

require 'undercover/lcov_parser'
require 'undercover/coverage_index'
require 'undercover/result'
require 'undercover/cli'
require 'undercover/changeset'
require 'undercover/formatter'
require 'undercover/json_formatter'
require 'undercover/options'
require 'undercover/coverage_root'
require 'undercover/filter_set'
require 'undercover/simplecov_result_adapter'
require 'undercover/version'
require 'undercover/node'
require 'undercover/node_visitor'
require 'undercover/erb_node'
require 'undercover/erb_visitor'
require 'undercover/erb_extractor'
require 'undercover/file_loader'

module Undercover
  class Report
    extend Forwardable
    include FileLoader

    def_delegators :changeset, :validate

    attr_reader :changeset,
                :lcov,
                :coverage_adapter,
                :results,
                :code_dir,
                :coverage_root,
                :filter_set,
                :max_warnings_limit

    # Initializes a new Undercover::Report
    #
    # @param changeset [Undercover::Changeset]
    # @param opts [Undercover::Options]
    # @param coverage_adapter [Undercover::SimplecovResultAdapter|Undercover::LcovParser] pre-parsed coverage adapter
    def initialize(changeset, opts, coverage_adapter)
      @coverage_adapter = coverage_adapter
      @changeset = changeset
      @code_dir = changeset.repo_workdir
      @coverage_root = resolve_coverage_root
      coverage_adapter.coverage_root = @coverage_root
      @filter_set = build_filter_set(opts)
      changeset.filter_with(filter_set)
      @max_warnings_limit = opts.max_warnings_limit
      @loaded_files = {}
      @results = {}
    end

    # rubocop:disable-next Metrics/MethodLength, Metrics/AbcSize
    def build
      flag_count = 0
      changeset.each_changed_line do |filepath, line_no|
        break if max_warnings_limit && flag_count >= max_warnings_limit

        load_and_parse_file(filepath)

        next unless loaded_files[filepath]

        res = result_for_line(filepath, line_no)
        if res.uncovered?(line_no) && !res.flagged?
          res.flag
          flag_count += 1
        end
        results[filepath] ||= Set.new
        results[filepath] << res
      end
      self
    end

    def build_warnings
      warn('Undercover::Report#build_warnings is deprecated! ' \
           'Please use the #flagged_results accessor instead.')
      all_results.select(&:flagged?)
    end

    def all_results
      results.values.map(&:to_a).flatten
    end

    def flagged_results
      all_results.select(&:flagged?)
    end

    # Changed files undercover would have reported on, had --include-files /
    # --exclude-files not rejected them. Everything rejected and nothing reported usually
    # means the globs are written against the wrong root.
    def globbed_out_files
      @globbed_out_files ||= changeset.file_paths.select { |path| filter_set.rejected_by_globs?(path) }
    end

    # Changed ERB templates left unchecked because the coverage report has no ERB coverage
    # at all, meaning SimpleCov ran without enable_coverage(:eval). Checking them anyway
    # would flag every block at 0%.
    def erb_files_without_coverage
      return [] if coverage_adapter.erb_coverage?

      @erb_files_without_coverage ||= changeset.file_paths.select do |path|
        path.end_with?(FileLoader::ERB_EXTENSION) && filter_set.include?(path)
      end
    end

    # Changed ERB templates left unchecked because they could not be parsed
    def erb_parse_failures
      @erb_parse_failures ||= []
    end

    def inspect
      "#<Undercover::Report:#{object_id} results: #{results.size}>"
    end
    alias to_s inspect

    private

    attr_reader :loaded_files

    # The innermost result whose lines cover line_no: the one starting closest above it,
    # the first one listed on a tie. Lines outside every result fall back to the first.
    def result_for_line(filepath, line_no)
      @line_results ||= {}
      by_line = @line_results[filepath] ||= index_results_by_line(loaded_files[filepath])
      by_line[line_no] || loaded_files[filepath].first
    end

    def index_results_by_line(file_results)
      by_line = {}
      file_results.each do |res|
        (res.first_line..res.last_line).each do |line_no|
          current = by_line[line_no]
          by_line[line_no] = res if current.nil? || res.first_line > current.first_line
        end
      end
      by_line
    end

    def build_filter_set(opts)
      FilterSet.new(opts.glob_allow_filters, opts.glob_reject_filters, coverage_adapter.ignored_files || [],
                    coverage_root: coverage_root)
    end

    # LCOV reports carry no SimpleCov.root, so fall back to where undercover runs, which
    # is where SimpleCov ran for anyone invoking the CLI by hand. A wrong guess is caught
    # by the covered-file check in CoverageRoot.
    def resolve_coverage_root
      simplecov_root = coverage_adapter.simplecov_root || Dir.pwd
      CoverageRoot.derive(code_dir, simplecov_root, coverage_adapter.coverage_keys, exists: method(:repository_path?))
    end

    # On disk, or committed at HEAD for files a sparse checkout left out
    def repository_path?(path)
      File.exist?(File.join(code_dir, path)) || changeset.head_path?(path)
    end
  end
end
