# frozen_string_literal: true

module Undercover
  LcovParseError = Class.new(StandardError)

  class LcovParser
    attr_reader :io, :source_files

    def initialize(lcov_io)
      @io = lcov_io
      @source_files = {}
    end

    def self.parse(lcov_report_path)
      lcov_io = File.open(lcov_report_path)
      new(lcov_io).parse
    end

    def parse
      io.each(&method(:parse_line))
      io.close
      self
    end

    def coverage(filepath)
      _filename, coverage = source_files.find do |relative_path, _|
        relative_path == filepath
      end
      coverage || []
    end

    private

    # rubocop:disable Metrics/MethodLength, Style/SpecialGlobalVars, Metrics/AbcSize
    def parse_line(line)
      case line
      when /^SF:(.+)/
        @current_filename = $~[1].gsub(/^\.\//, '')
        source_files[@current_filename] = []
      when /^DA:(\d+),(\d+)/
        line_no = $~[1]
        covered = $~[2]
        source_files[@current_filename] << [line_no.to_i, covered.to_i]
      when /^(BRF|BRH):(\d+)/
        # branches found/hit; no-op
      when /^BRDA:(\d+),(\d+),(\d+),(-|\d+)/
        line_no = $~[1]
        block_no = $~[2]
        branch_no = $~[3]
        covered = ($~[4] == '-' ? '0' : $~[4])
        source_files[@current_filename] << [line_no.to_i, block_no.to_i, branch_no.to_i, covered.to_i]
      when /^end_of_record$/, /^$/
        @current_filename = nil
      else
        raise LcovParseError, "could not recognise '#{line}' as valid LCOV"
      end
    end
    # rubocop:enable Metrics/MethodLength, Style/SpecialGlobalVars, Metrics/AbcSize
  end
end
