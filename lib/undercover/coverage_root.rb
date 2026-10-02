# frozen_string_literal: true

require 'pathname'

module Undercover
  # Coverage reports record paths relative to SimpleCov.root, while a changeset records
  # them relative to the git repository root. In a monorepo the two differ by a directory
  # prefix, e.g. coverage says "main.rb" where git says "apps/dash/main.rb".
  #
  # SimpleCov.root is stored in the report, but as an absolute path from whichever machine
  # ran the tests, which need not exist where undercover runs. Its tail still names the
  # directory though, so match the longest tail that exists in the repository.
  module CoverageRoot
    NONE = ''

    # Coverage keys checked when confirming a candidate. A handful is enough to tell a
    # real match from a directory that merely shares a name.
    SAMPLE_SIZE = 20

    # @param git_root [String] absolute path to the repository working directory
    # @param simplecov_root [String, nil] SimpleCov.root as recorded in the report
    # @param coverage_keys [Array<String>] paths relative to SimpleCov.root, used to
    #   confirm a candidate actually holds the covered files
    # @return [String] prefix that joins a coverage key onto a repository path,
    #   NONE when coverage was recorded at the repository root or cannot be placed
    def self.derive(git_root, simplecov_root, coverage_keys = nil)
      return NONE if git_root.nil? || simplecov_root.nil? || simplecov_root.empty?

      candidates(git_root, simplecov_root).find do |prefix|
        holds_covered_files?(git_root, prefix, coverage_keys)
      end || NONE
    end

    # @return [String] filepath relative to the coverage root
    def self.strip(filepath, root)
      return filepath if root.nil? || root.empty?

      filepath.delete_prefix("#{root}/")
    end

    # @return [Boolean] whether a repository path lives under the coverage root
    def self.under?(filepath, root)
      return true if root.nil? || root.empty?

      filepath.start_with?("#{root}/")
    end

    # Tails of SimpleCov.root that exist in the repository, longest first. "/build/x/app"
    # offers "app", then "x/app", then "build/x/app"; the longest that exists wins, so a
    # nested app beats a directory that happens to share its leaf name.
    def self.candidates(git_root, simplecov_root)
      parts = Pathname.new(simplecov_root).each_filename.to_a
      (1..parts.length)
        .map { |depth| parts.last(depth).join('/') }
        .select { |prefix| Dir.exist?(File.join(git_root, prefix)) }
        .sort_by { |prefix| -prefix.length }
    end
    private_class_method :candidates

    # Guards against a coincidence: the repository may contain a directory named like
    # SimpleCov.root's leaf without being the place the coverage came from.
    def self.holds_covered_files?(git_root, prefix, coverage_keys)
      keys = Array(coverage_keys).reject { |key| key.nil? || key.empty? }
      return true if keys.empty?

      keys.first(SAMPLE_SIZE).any? { |key| File.exist?(File.join(git_root, prefix, key)) }
    end
    private_class_method :holds_covered_files?
  end
end
