# frozen_string_literal: true

require 'optparse'
require 'pathname'

module Undercover
  class Options
    RUN_MODE = [
      RUN_MODE_DIFF_STRICT = :diff_strict, # warn for changed lines
      # RUN_MODE_DIFF_FILES  = :diff_files, # warn for changed whole files
      # RUN_MODE_ALL         = :diff_all, # warn for allthethings
      # RUN_MODE_FILES       = :files # warn for specific files (cli option)
    ].freeze

    OUTPUT_FORMATTERS = [
      OUTPUT_STDOUT = :stdout, # outputs warnings to stdout with exit 1
      # OUTPUT_CIRCLEMATOR = :circlemator # posts warnings as review comments
    ].freeze

    attr_accessor :lcov, :path, :git_dir, :compare

    def initialize
      # TODO: use run modes
      # TODO: use formatters
      @run_mode = RUN_MODE_DIFF_STRICT
      @enabled_formatters = [OUTPUT_STDOUT]
      # set defaults
      self.lcov = guess_lcov_path
      self.path = '.'
      self.git_dir = '.git'
    end

    # rubocop:disable Metrics/MethodLength
    def parse(args)
      OptionParser.new do |opts|
        opts.banner = 'Usage: example.rb [options]'

        opts.on_tail('-h', '--help', 'Prints this help') do
          puts(opts)
          exit
        end

        opts.on_tail('--version', 'Show version') do
          puts Version
          exit
        end

        lcov_path_option(opts)
        project_path_option(opts)
        git_dir_option(opts)
        compare_option(opts)
        # TODO: parse dem other options and assign to self
        # --quiet (skip progress bar)
        # --exit-status (do not print report, just exit)
        # --ruby-version (string, like '2.4.4', how to support in parser?)
      end.parse(args)
      self
    end
    # rubocop:enable Metrics/MethodLength

    private

    def lcov_path_option(parser)
      parser.on('-l', '--lcov path', 'LCOV report file path') do |path|
        self.lcov = path
      end
    end

    def project_path_option(parser)
      parser.on('-p', '--path path', 'Project directory') do |path|
        self.path = path
      end
    end

    def git_dir_option(parser)
      desc = 'Override `.git` with a custom directory'
      parser.on('-g', '--git-dir dir', desc) do |dir|
        self.git_dir = dir
      end
    end

    def compare_option(parser)
      desc = 'Generate coverage warnings for all changes after `ref`'
      parser.on('-c', '--compare ref', desc) do |ref|
        self.compare = ref
      end
    end

    def guess_lcov_path
      pwd = Pathname.pwd
      File.join(pwd, 'coverage', 'lcov', "#{pwd.split.last}.lcov")
    end
  end
end
