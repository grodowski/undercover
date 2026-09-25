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
      fnmatch = proc { |glob| File.fnmatch(glob, relative, File::FNM_EXTGLOB) }

      # Check if file was ignored by SimpleCov filters
      return false if ignored_by_simplecov?(relative)

      # Apply Undercover's own filters
      allow_filters.any?(fnmatch) && reject_filters.none?(fnmatch)
    end

    private

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
