# frozen_string_literal: true

require 'rugged'
require 'time'

module Undercover
  # Base class for different kinds of input
  class Changeset
    T_ZERO = Time.strptime('0', '%s').freeze

    def initialize(dir, compare_base = nil, filter_set = nil, commits_only: false)
      raise ArgumentError, 'commits_only requires a compare_base' if commits_only && !compare_base

      @dir = dir
      @repo = Rugged::Repository.new(dir)
      @repo.workdir = Pathname.new(dir).dirname.to_s # TODO: can replace?
      @compare_base = compare_base
      @filter_set = filter_set
      @commits_only = commits_only
    end

    # @return String absolute path to the repository working directory
    def repo_workdir
      repo.workdir
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
      full_diff.deltas.map { |d| d.new_file[:path] }.sort
    end

    def each_changed_line
      full_diff.each_patch do |patch|
        filepath = patch.delta.new_file[:path]
        next if filter_set && !filter_set.include?(filepath)

        patch.each_hunk do |hunk|
          hunk.lines.select(&:addition?).each do |line|
            yield filepath, line.new_lineno
          end
        end
      end
    end

    def validate(lcov_report_path)
      return :no_changes if full_diff.deltas.empty?

      :stale_coverage if last_modified > File.mtime(lcov_report_path)
    end

    def filter_with(filter_set)
      @filter_set = filter_set
    end

    private

    # Diffs `head` or `head` + `compare_base` (if exists),
    # as it makes sense to run Undercover with the most recent file versions.
    # With `commits_only`, diffs `compare_base` against `head` and ignores the index and
    # working tree, so files missing from a sparse checkout are not reported as deleted.
    def full_diff
      @full_diff ||= if commits_only
                       compare_base_obj.diff(head)
                     else
                       (compare_base_obj || head).diff(repo.index).merge!(repo.diff_workdir(head))
                     end
    end

    def compare_base_obj
      return nil unless compare_base

      merge_base = repo.merge_base(compare_base.to_s, head)
      # merge_base may be nil with --depth 1, compare two refs directly
      merge_base ? repo.lookup(merge_base) : repo.rev_parse(compare_base)
    end

    def head
      repo.head.target
    end

    attr_reader :repo, :compare_base, :filter_set, :commits_only
  end
end
