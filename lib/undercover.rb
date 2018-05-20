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
    # @param options [Undercover::Options]
    def initialize(opts)
      @lcov = LcovParser.parse(File.open(opts.lcov))
      @code_dir = opts.path
      git_dir = File.join(opts.path, opts.git_dir)
      @changeset = Changeset.new(git_dir, opts.compare).update
      @results = Hash.new { |hsh, key| hsh[key] = [] }
    end

    def build
      each_result_arg do |filename, coverage, imagen_node|
        results[filename.gsub(/^\.\//, '')] << Result.new(
          imagen_node, coverage, filename
        )
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

    # TODO: should that start from changeset.file_paths?
    # this way we could report things that weren't even loaded in any spec,
    # so is this still good idea? (Rakefile, .gemspec etc)
    def each_result_arg
      match_all = ->(_) { true }
      lcov.source_files.each do |filename, coverage|
        path = File.join(code_dir, filename)
        root_ast = Imagen::Node::Root.new.build_from_file(path)
        next if root_ast.children.empty?
        root_ast.children[0].find_all(match_all).each do |node|
          yield(path, coverage, node)
        end
      end
    end
  end
end
