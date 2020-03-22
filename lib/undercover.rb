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
                :code_dir

    # Initializes a new Undercover::Report
    #
    # @param changeset [Undercover::Changeset]
    # @param opts [Undercover::Options]
    def initialize(changeset, opts)
      @lcov = LcovParser.parse(File.open(opts.lcov))
      @code_dir = opts.path
      @changeset = changeset.update
      @results = {}
    end

    def build
      build_warnings
      self
    end

    # rubocop:disable Metrics/MethodLength, Metrics/AbcSize
    def build_warnings
      flagged_results = Set.new

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
        lazy_load_file(filepath)

        next unless results[filepath]

        res = results[filepath].min(&dist_from_line_no_sorter)
        flagged_results << res if res&.uncovered?(line_no)
      end
      flagged_results
    end
    # rubocop:enable Metrics/MethodLength, Metrics/AbcSize

    def all_results
      results.values.flatten
    end

    def inspect
      "#<Undercover::Report:#{object_id} results: #{results.size}>"
    end
    alias to_s inspect

    private

    # rubocop:disable Metrics/MethodLength, Metrics/AbcSize
    def lazy_load_file(filepath)
      key = filepath.gsub(/^\.\//, '')
      return if results[key]

      coverage = lcov.coverage(filepath)
      return if coverage.empty?

      root_ast = Imagen::Node::Root.new.build_from_file(
        File.join(code_dir, filepath)
      )
      return if root_ast.children.empty?

      results[key] = []
      root_ast.children[0].find_all(->(_) { true }).each do |imagen_node|
        results[key] << Result.new(
          imagen_node, coverage, filepath
        )
      end
    end
    # rubocop:enable Metrics/MethodLength, Metrics/AbcSize
  end
end
