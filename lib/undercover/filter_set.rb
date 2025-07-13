# frozen_string_literal: true

module Undercover
  class FilterSet
    attr_reader :allow_filters, :reject_filters

    def initialize(allow_filters, reject_filters)
      @allow_filters = allow_filters || []
      @reject_filters = reject_filters || []
    end

    def include?(filepath)
      fnmatch = proc { |glob| File.fnmatch(glob, filepath, File::FNM_EXTGLOB) }
      allow_filters.any?(fnmatch) && reject_filters.none?(fnmatch)
    end
  end
end
