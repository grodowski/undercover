# frozen_string_literal: true

require 'rugged'
require 'time'

module Undercover
  # Base class for different kinds of input
  class Changeset
    T_ZERO = Time.strptime('0', '%s').freeze

    extend Forwardable
    include Enumerable

    attr_reader :files
    def_delegators :files, :each, :'<=>'

    def initialize(dir, compare_base = nil)
      @dir = dir
      @repo = Rugged::Repository.new(dir)
      @repo.workdir = Pathname.new(dir).dirname.to_s # TODO: can replace?
      @compare_base = compare_base
      @files = {}
    end

    def update
      full_diff.each_patch do |patch|
        filepath = patch.delta.new_file[:path]
        line_nums = patch.each_hunk.map do |hunk|
          # TODO: optimise this to use line ranges!
          hunk.lines.select(&:addition?).map(&:new_lineno)
        end.flatten
        @files[filepath] = line_nums if line_nums.any?
      end
      self
    end

    def last_modified
      mod = file_paths.map do |f|
        path = File.join(repo.workdir, f)
        next T_ZERO unless File.exist?(path)

        File.mtime(path)
      end.max
      mod || T_ZERO
    end

    def file_paths
      files.keys.sort
    end

    def each_changed_line
      files.each do |filepath, line_numbers|
        line_numbers.each { |ln| yield filepath, ln }
      end
    end

    # TODO: refactor to a standalone validator (depending on changeset AND lcov)
    # TODO: add specs
    def validate(lcov_report_path)
      return :no_changes if files.empty?
      return :stale_coverage if last_modified > File.mtime(lcov_report_path)
    end

    private

    # Diffs `head` or `head` + `compare_base` (if exists),
    # as it makes sense to run Undercover with the most recent file versions
    def full_diff
      base = compare_base_obj || head
      base.diff(repo.index).merge!(repo.diff_workdir(head))
    end

    def compare_base_obj
      return nil unless compare_base

      repo.lookup(repo.merge_base(compare_base.to_s, head))
    end

    def head
      repo.head.target
    end

    attr_reader :repo, :compare_base
  end
end
