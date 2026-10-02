# frozen_string_literal: true

module Undercover
  class FilterSet
    attr_reader :allow_filters, :reject_filters, :simplecov_filters, :coverage_root

    def initialize(allow_filters, reject_filters, simplecov_filters, coverage_root: CoverageRoot::NONE)
      @allow_filters = allow_filters || []
      @reject_filters = reject_filters || []
      @simplecov_filters = simplecov_filters || []
      @coverage_root = coverage_root || CoverageRoot::NONE
    end

    # @param filepath[String] path relative to the git repository root
    def include?(filepath)
      # Changes outside the coverage root belong to a different project in the same
      # repository and have no coverage data to judge them by.
      return false unless CoverageRoot.under?(filepath, coverage_root)

      # Every filter below is written relative to SimpleCov.root, so compare there.
      relative = CoverageRoot.strip(filepath, coverage_root)

      # Check if file was ignored by SimpleCov filters
      return false if ignored_by_simplecov?(relative)

      # Apply Undercover's own filters
      matches_globs?(relative)
    end

    # A file undercover would otherwise have reported on, dropped only by --include-files
    # or --exclude-files. Used to tell a misconfigured glob apart from a clean run.
    # @param filepath[String] path relative to the git repository root
    def rejected_by_globs?(filepath)
      return false unless CoverageRoot.under?(filepath, coverage_root)

      relative = CoverageRoot.strip(filepath, coverage_root)
      return false if ignored_by_simplecov?(relative)

      !matches_globs?(relative)
    end

    private

    def matches_globs?(relative)
      fnmatch = proc { |glob| File.fnmatch(glob, relative, File::FNM_EXTGLOB) }
      allow_filters.any?(fnmatch) && reject_filters.none?(fnmatch)
    end

    def ignored_by_simplecov?(filepath)
      simplecov_filters.any? do |filter|
        filter = filter.transform_keys(&:to_sym)
        if filter[:string]
          normalize_slash(filepath).include?(filter[:string])
        elsif filter[:regex]
          normalize_slash(filepath).match?(Regexp.new(filter[:regex]))
        elsif filter[:file]
          filepath == filter[:file]
        end
      end
    end

    # SimpleCov's 'rails' profile adds regex filters that start with a slash by default. Let's be compatible.
    def normalize_slash(filepath)
      filepath.start_with?('/') ? filepath : "/#{filepath}"
    end
  end
end
