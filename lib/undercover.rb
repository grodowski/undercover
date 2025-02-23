# frozen_string_literal: true

$LOAD_PATH << 'lib'
require 'imagen'
require 'rainbow'
require 'bigdecimal'
require 'forwardable'

require 'undercover/lcov_parser'
require 'undercover/result'
require 'undercover/cli'
require 'undercover/changeset'
require 'undercover/formatter'
require 'undercover/options'
require 'undercover/version'

module Undercover
  class Report
    extend Forwardable
    def_delegators :changeset, :validate

    attr_reader :changeset,
                :lcov,
                :results,
                :code_dir,
                :glob_filters

    # Initializes a new Undercover::Report
    #
    # @param changeset [Undercover::Changeset]
    # @param opts [Undercover::Options]
    def initialize(changeset, opts)
      @lcov = LcovParser.parse(File.open(opts.lcov))
      @code_dir = opts.path
      @changeset = changeset.update
      @glob_filters = {
        allow: opts.glob_allow_filters,
        reject: opts.glob_reject_filters
      }
      @loaded_files = {}
      @results = {}
    end

    # rubocop:disable Metrics/MethodLength, Metrics/AbcSize
    def build
      changeset.each_changed_line do |filepath, line_no|
        dist_from_line_no = lambda do |res|
          return BigDecimal::INFINITY if line_no < res.first_line

          res_lines = res.first_line..res.last_line
          return BigDecimal::INFINITY unless res_lines.cover?(line_no)

          line_no - res.first_line
        end
        dist_from_line_no_sorter = lambda do |res1, res2|
          dist_from_line_no[res1] <=> dist_from_line_no[res2]
        end

        load_and_parse_file(filepath)

        next unless loaded_files[filepath]

        res = loaded_files[filepath].min(&dist_from_line_no_sorter)
        res.flag if res&.uncovered?(line_no)
        results[filepath] ||= Set.new
        results[filepath] << res
      end
      self
    end
    # rubocop:enable Metrics/MethodLength, Metrics/AbcSize

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

    def inspect
      "#<Undercover::Report:#{object_id} results: #{results.size}>"
    end
    alias to_s inspect

    private

    attr_reader :loaded_files

    # rubocop:disable Metrics/MethodLength, Metrics/AbcSize
    def load_and_parse_file(filepath)
      key = filepath.gsub(/^\.\//, '')
      return if loaded_files[key]

      coverage = lcov.coverage(filepath)

      return unless include_file?(filepath)

      root_ast = Imagen::Node::Root.new.build_from_file(
        File.join(code_dir, filepath)
      )
      return if root_ast.children.empty?

      loaded_files[key] = []
      root_ast.children[0].find_all(->(_) { true }).each do |imagen_node|
        loaded_files[key] << Result.new(imagen_node, coverage, filepath)
      end
    end
    # rubocop:enable Metrics/MethodLength, Metrics/AbcSize

    def include_file?(filepath)
      fnmatch = proc { |glob| File.fnmatch(glob, filepath) }
      glob_filters[:allow].any?(fnmatch) && glob_filters[:reject].none?(fnmatch)
    end
  end
end
