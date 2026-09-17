# frozen_string_literal: true

module Undercover
  # Coverage reports record paths relative to SimpleCov.root, while a changeset records
  # them relative to the git repository root. In a monorepo the two differ by a directory
  # prefix, e.g. coverage says "main.rb" where git says "apps/dash/main.rb".
  #
  # The prefix is derived by matching coverage keys onto repository paths. That keeps it
  # independent of absolute paths - SimpleCov.root is recorded on whichever machine ran
  # the tests and need not exist where undercover runs - and of the directory undercover
  # is invoked from.
  module CoverageRoot
    NONE = ''

    # @param repo_paths [Array<String>] paths relative to the repository root
    # @param coverage_keys [Array<String>] paths relative to SimpleCov.root
    # @return [String] prefix that joins a coverage key onto a repository path,
    #   NONE when both roots are the same or the prefix cannot be determined
    def self.derive(repo_paths, coverage_keys)
      keys = Array(coverage_keys).reject { |k| k.nil? || k.empty? }
      paths = Array(repo_paths)
      return NONE if keys.empty? || paths.empty?

      candidates = keys.map { |key| prefixes_for(paths, key) }.reduce(:&) || []
      candidates.size == 1 ? candidates.first : NONE
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

    def self.prefixes_for(paths, key)
      matcher = /\A(?:(.+)\/)?#{Regexp.escape(key)}\z/
      paths.filter_map do |path|
        match = matcher.match(path)
        match && (match[1] || NONE)
      end.uniq
    end
    private_class_method :prefixes_for
  end
end
