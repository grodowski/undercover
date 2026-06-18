# frozen_string_literal: true

require 'git'
require 'pathname'

module Undercover
  class Changeset
    class GitAdapter
      HUNK_HEADER = /^@@ -\d+(?:,\d+)? \+(\d+)(?:,\d+)? @@/

      def initialize(dir, compare_base = nil)
        git_dir = File.expand_path(dir)
        @workdir = Pathname.new(git_dir).dirname.to_s
        @repo = Git.open(@workdir, repository: git_dir)
        @compare_base = compare_base
      end

      attr_reader :workdir

      def changed_files
        diff_files.map(&:path).sort
      end

      def each_added_line
        diff_files.each do |fd|
          patch = fd.patch
          next if patch.nil? || patch.empty?

          parse_added_lines(patch) do |lineno|
            yield fd.path, lineno
          end
        end
      end

      def empty?
        diff_files.none?
      end

      private

      attr_reader :repo, :compare_base

      def diff_files
        @diff_files ||= repo.diff(diff_base).to_a
      end

      def diff_base
        return 'HEAD' unless compare_base

        merge_base_sha || compare_base.to_s
      end

      def merge_base_sha
        commits = repo.merge_base(compare_base.to_s, 'HEAD')
        commits.first&.sha
      rescue Git::FailedError, ArgumentError
        nil
      end

      def parse_added_lines(patch)
        new_lineno = nil
        patch.each_line do |line|
          if (m = line.match(HUNK_HEADER))
            new_lineno = m[1].to_i
          elsif new_lineno
            yield new_lineno if added_line?(line)
            new_lineno += 1 if added_line?(line) || context_line?(line)
          end
        end
      end

      def added_line?(line)
        line.start_with?('+') && !line.start_with?('+++')
      end

      def context_line?(line)
        line.start_with?(' ')
      end
    end
  end
end
