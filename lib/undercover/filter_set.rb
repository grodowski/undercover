# frozen_string_literal: true

module Undercover
  class FilterSet
    include RootToRelativePaths

    attr_reader :allow_filters, :reject_filters, :simplecov_filters

    def initialize(allow_filters, reject_filters, simplecov_filters, path: nil)
      @allow_filters = allow_filters || []
      @reject_filters = reject_filters || []
      @simplecov_filters = simplecov_filters || []
      @code_dir = path
    end

    def include?(filepath)
      path_sans_prefix = fix_relative_filepath(filepath)
      fnmatch = proc do |glob|
        File.fnmatch(glob, path_sans_prefix, File::FNM_EXTGLOB)
      end

      # Check if file was ignored by SimpleCov filters
      return false if ignored_by_simplecov?(path_sans_prefix)

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
