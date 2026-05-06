# frozen_string_literal: true

require 'time'

module Undercover
  # Base class for different kinds of input
  class Changeset
    T_ZERO = Time.strptime('0', '%s').freeze

    def self.default_adapter_class
      require 'undercover/changeset/rugged_adapter'
      RuggedAdapter
    rescue LoadError
      require 'undercover/changeset/git_adapter'
      GitAdapter
    end

    def initialize(dir, compare_base = nil, filter_set = nil, adapter: nil)
      @adapter = adapter || self.class.default_adapter_class.new(dir, compare_base)
      @filter_set = filter_set
    end

    def last_modified
      mod = file_paths.map do |f|
        path = File.join(@adapter.workdir, f)
        next T_ZERO unless File.exist?(path)

        File.mtime(path)
      end.max
      mod || T_ZERO
    end

    def file_paths
      @adapter.changed_files
    end

    def each_changed_line
      @adapter.each_added_line do |filepath, lineno|
        next if filter_set && !filter_set.include?(filepath)

        yield filepath, lineno
      end
    end

    def validate(lcov_report_path)
      return :no_changes if @adapter.empty?

      :stale_coverage if last_modified > File.mtime(lcov_report_path)
    end

    def filter_with(filter_set)
      @filter_set = filter_set
    end

    private

    attr_reader :filter_set
  end
end
