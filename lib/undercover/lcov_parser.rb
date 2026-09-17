# frozen_string_literal: true

require 'undercover/coverage_root'

module Undercover
  class LcovParseError < StandardError
  end

  class LcovParser
    attr_reader :io, :source_files
    attr_accessor :coverage_root

    def initialize(lcov_io, _opts = nil, only_files: nil)
      @io = lcov_io
      @source_files = {}
      @only_files = only_files
      @coverage_root = CoverageRoot::NONE
    end

    def self.parse(lcov_report_path, opts = nil, only_files: nil)
      lcov_io = File.open(lcov_report_path)
      new(lcov_io, opts, only_files: only_files).parse
    end

    def parse
      derive_coverage_root if @only_files
      io.each(&method(:parse_line))
      io.close
      self
    end

    # @return Array paths relative to SimpleCov.root
    def coverage_keys
      source_files.keys
    end

    def coverage(filepath)
      source_files[CoverageRoot.strip(filepath, coverage_root)] || []
    end

    def total_coverage
      all_lines = source_files.values.flatten(1)
      return 0 if all_lines.empty?

      all_lines = all_lines.select { _1.size == 2 }
      total_f = all_lines.select { |_line_no, hits| hits.positive? }.size.to_f / all_lines.size
      total_f.round(3)
    end

    def total_branch_coverage
      all_lines = source_files.values.flatten(1)
      return 0 if all_lines.empty?

      all_branches = all_lines.select { _1.size == 4 }
      total_f = all_branches.select { |_l_no, _block_no, _br_no, hits| hits.positive? }.size.to_f / all_branches.size
      total_f.round(3)
    end

    def skipped?(_filepath, _line_no)
      # this is why lcov parser will be deprecated
      false
    end

    def branch_label(_filepath, _branch_no)
      nil
    end

    def ignored_files
      # supported by SimplecovResultAdapter only
      []
    end

    private

    # Scans SF: records only, so the prefix is known before any line data is held
    # in memory and only_files can be matched at the coverage root.
    def derive_coverage_root
      names = io.each_line.filter_map { |line| line[/^SF:(.+)/, 1]&.gsub(/^\.\//, '') }
      @coverage_root = CoverageRoot.derive(@only_files, names)
      @wanted = @only_files.to_set { |f| CoverageRoot.strip(f, @coverage_root) }
      io.rewind
    end

    # rubocop:disable Metrics/MethodLength, Metrics/CyclomaticComplexity, Style/SpecialGlobalVars, Metrics/AbcSize
    def parse_line(line)
      case line
      when /^SF:(.+)/
        filename = $~[1].gsub(/^\.\//, '')
        @current_filename = @wanted.nil? || @wanted.include?(filename) ? filename : nil
        source_files[@current_filename] = [] if @current_filename
      when /^DA:(\d+),(\d+)/
        return unless @current_filename

        line_no = $~[1]
        covered = $~[2]
        source_files[@current_filename] << [line_no.to_i, covered.to_i]
      when /^(BRF|BRH):(\d+)/
        # branches found/hit; no-op
      when /^BRDA:(\d+),(\d+),(\d+),(-|\d+)/
        return unless @current_filename

        line_no = $~[1]
        block_no = $~[2]
        branch_no = $~[3]
        covered = ($~[4] == '-' ? '0' : $~[4])
        source_files[@current_filename] << [line_no.to_i, block_no.to_i, branch_no.to_i, covered.to_i]
      when /^end_of_record$/, /^$/
        @current_filename = nil
      when /^LF:(\d+)|LH:(\d+)/ # lines found, lines hit; no-op
      else
        raise LcovParseError, "could not recognise '#{line}' as valid LCOV"
      end
    end
    # rubocop:enable Metrics/MethodLength, Metrics/CyclomaticComplexity, Style/SpecialGlobalVars, Metrics/AbcSize
  end
end
