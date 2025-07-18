# frozen_string_literal: true

module Undercover
  class FilterSet
    attr_reader :allow_filters, :reject_filters, :simplecov_ignored_files

    def initialize(allow_filters, reject_filters, simplecov_ignored_files)
      @allow_filters = allow_filters || []
      @reject_filters = reject_filters || []
      @simplecov_ignored_files = simplecov_ignored_files
    end

    def include?(filepath)
      fnmatch = proc { |glob| File.fnmatch(glob, filepath, File::FNM_EXTGLOB) }

      # Check if file was ignored by SimpleCov filters
      return false if simplecov_ignored_files.include?(filepath)

      # Apply Undercover's own filters
      allow_filters.any?(fnmatch) && reject_filters.none?(fnmatch)
    end
  end
end
