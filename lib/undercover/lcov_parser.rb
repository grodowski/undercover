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

    private

    # rubocop:disable Metrics/MethodLength, Style/SpecialGlobalVars
    def parse_line(line)
      case line
      when /^SF:([\.\/\w]+)/
        @current_filename = $~[1].gsub(/^\.\//, '')
        source_files[@current_filename] = []
      when /^DA:(\d+),(\d+)/
        line_no = $~[1]
        covered = $~[2]
        source_files[@current_filename] << [line_no.to_i, covered.to_i]
      when /^end_of_record$/, /^$/
        @current_filename = nil
      else
        raise LcovParseError, "could not recognise '#{line}' as valid LCOV"
      end
    end
    # rubocop:enable Metrics/MethodLength, Style/SpecialGlobalVars
  end
end
