# frozen_string_literal: true

$LOAD_PATH << 'lib'
require 'imagen'
require 'rainbow'
require 'bigdecimal'

require 'undercover/version'
require 'undercover/lcov_parser'
require 'undercover/result'
require 'undercover/cli'
require 'undercover/changeset'
require 'undercover/formatter'
require 'undercover/options'

module Undercover
  class Report
    attr_reader :changeset,
                :code_structure,
                :lcov,
                :results

    # TODO: pass merge base as cli argument
    # add dependecy on "options" for all opts (dirs, git_dir, etc)
    def initialize(lcov_report_path, code_dir, git_dir: '.git', compare: nil)
      @lcov = LcovParser.parse(File.open(lcov_report_path))
      # TODO: optimise by building changeset structure only!
      @code_structure = Imagen.from_local(code_dir)
      @changeset = Changeset.new(File.join(code_dir, git_dir), compare)
      @results = Hash.new { |hsh, key| hsh[key] = [] }
    end

    def build
      changeset.update
      each_result_arg do |filename, coverage, imagen_node|
        results[filename] << Result.new(imagen_node, coverage, filename)
      end
      self
    end

    # TODO: this is experimental and might be incorrect!
    # rubocop:disable Metrics/MethodLength, Metrics/AbcSize
    def build_warnings
      flagged_results = Set.new
      changeset.each_changed_line do |filepath, line_no|
        dist_from_line_no = lambda do |res|
          return BigDecimal::INFINITY if line_no < res.first_line
          line_no - res.first_line
        end
        dist_from_line_no_sorter = lambda do |res1, res2|
          dist_from_line_no[res1] <=> dist_from_line_no[res2]
        end

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

    def each_result_arg
      matches_path = lambda do |path|
        ->(node) { node.file_path.end_with?(path) }
      end

      lcov.source_files.each do |filename, coverage|
        code_structure.find_all(matches_path[filename]).each do |node|
          yield(filename, coverage, node)
        end
      end
    end
  end
end
