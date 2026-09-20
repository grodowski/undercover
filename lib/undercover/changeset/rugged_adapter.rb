# frozen_string_literal: true

require 'rugged'
require 'pathname'

module Undercover
  class Changeset
    class RuggedAdapter
      def initialize(dir, compare_base = nil)
        @repo = Rugged::Repository.new(dir)
        @repo.workdir = Pathname.new(dir).dirname.to_s
        @compare_base = compare_base
      end

      def workdir
        @repo.workdir
      end

      def changed_files
        full_diff.deltas.map { |d| d.new_file[:path] }.sort
      end

      def each_added_line
        full_diff.each_patch do |patch|
          filepath = patch.delta.new_file[:path]
          patch.each_hunk do |hunk|
            hunk.lines.select(&:addition?).each do |line|
              yield filepath, line.new_lineno
            end
          end
        end
      end

      def empty?
        full_diff.deltas.empty?
      end

      private

      attr_reader :repo, :compare_base

      def full_diff
        base = compare_base_obj || head
        @full_diff ||= base.diff(repo.index).merge!(repo.diff_workdir(head))
      end

      def compare_base_obj
        return nil unless compare_base

        merge_base = repo.merge_base(compare_base.to_s, head)
        merge_base ? repo.lookup(merge_base) : repo.rev_parse(compare_base)
      end

      def head
        repo.head.target
      end
    end
  end
end
