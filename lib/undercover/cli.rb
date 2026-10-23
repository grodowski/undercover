# frozen_string_literal: true

require 'undercover'
require 'rainbow'
require 'benchmark'

module Undercover
  module CLI # rubocop:disable Metrics/ModuleLength
    HINTS = {
      undercover_ci: 'UndercoverCI shows these results on your pull requests: https://undercover-ci.com ' \
                     '(hide with --no-hint)',
      claude_code: 'undercover has a Claude Code skill: https://github.com/grodowski/undercover-claude ' \
                   '(hide with --no-hint)'
    }.freeze

    def self.run(args, timed: false)
      opts = Undercover::Options.new.parse(args)
      syntax_version(opts.syntax_version)
      # Text after the JSON document would break parsing it
      return run_report(opts) if !timed || opts.formatter == 'json'

      result = nil
      time = Benchmark.realtime { result = run_report(opts) }
      puts "Undercover finished in #{time.round(4)}s"
      result
    end

    def self.run_report(opts) # rubocop:disable Metrics/AbcSize,Metrics/MethodLength
      coverage_path = opts.simplecov_resultset || opts.lcov
      return handle_missing_coverage_path(opts) if coverage_path.nil?
      return handle_missing_file(coverage_path) unless File.exist?(coverage_path)
      return handle_commits_only_without_compare if opts.commits_only && !opts.compare

      changeset_obj = changeset(opts)
      only_files = changeset_obj.file_paths.then { |f| f.empty? ? nil : f }

      simplecov_adapter = if opts.simplecov_resultset
                            SimplecovResultAdapter.parse(File.open(opts.simplecov_resultset), opts,
                                                         only_files: only_files)
                          else
                            # TODO: lcov will be deprecated end of 2025 and we'll be able to refactor harder
                            LcovParser.parse(File.open(opts.lcov), opts, only_files: only_files)
                          end

      report = Undercover::Report.new(changeset_obj, opts, simplecov_adapter).build
      handle_report_validation(report, coverage_path, opts)
    end

    def self.handle_missing_coverage_path(_opts = nil)
      puts Rainbow('❌ ERROR: No coverage report found. Checked default paths:').red
      puts Rainbow('  - ./coverage/coverage.json (SimpleCov)').red
      puts Rainbow("  - ./coverage/lcov/#{Pathname.new(Dir.pwd).split.last}.lcov (LCOV)").red
      puts Rainbow('Set a custom path with --lcov or --simplecov option').red
      1
    end

    def self.handle_missing_file(coverage_path)
      puts Rainbow("❌ ERROR: Coverage report not found at: #{coverage_path}").red
      1
    end

    def self.handle_commits_only_without_compare
      puts Rainbow('❌ ERROR: --commits-only requires --compare ref').red
      1
    end

    def self.handle_report_validation(report, coverage_path, opts)
      validation_error = report.validate(coverage_path)
      flagged = validation_error ? [] : report.flagged_results
      unless validation_error
        warn_if_erb_has_no_coverage(report)
        warn_if_everything_was_globbed_out(report, opts)
      end
      formatter = build_formatter(flagged, validation_error, opts)

      puts formatter
      hint_for(opts)&.then { warn(_1) }
      formatter.exit_code
    end

    def self.hint_for(opts, env = ENV)
      return if opts.formatter == 'json' || opts.no_hint || !env['UNDERCOVER_NO_HINT'].to_s.empty?

      env['CLAUDECODE'].to_s.empty? ? HINTS[:undercover_ci] : HINTS[:claude_code]
    end

    # Reporting nothing because every candidate was filtered out looks identical to a
    # clean run, so say which it was. Goes to stderr to leave --format json parseable.
    def self.warn_if_everything_was_globbed_out(report, opts)
      return unless report.results.empty?

      skipped = report.globbed_out_files
      return if skipped.empty?
      return warn_erb_is_opt_in(skipped) if erb_not_opted_in?(skipped, opts)
      return warn_globbed_out_besides_erb(skipped) if report.erb_files_without_coverage.any?

      warn(Rainbow("⚠️  WARNING: nothing was checked - all #{skipped.size} candidate file(s) were " \
                   'skipped by --include-files/--exclude-files. Globs are matched relative to the ' \
                   'directory SimpleCov covered, so they should not repeat its path.').yellow)
    end

    # Templates skipped for lack of coverage were candidates too, so not everything was globbed out
    def self.warn_globbed_out_besides_erb(skipped)
      warn(Rainbow("⚠️  WARNING: besides those ERB templates, #{skipped.size} candidate file(s) were skipped " \
                   'by --include-files/--exclude-files.').yellow)
    end

    # The default globs skip ERB templates, so blaming the glob root would mislead
    def self.erb_not_opted_in?(skipped, opts)
      skipped.any? { _1.end_with?(FileLoader::ERB_EXTENSION) } &&
        opts.glob_allow_filters.none? { _1.include?(FileLoader::ERB_EXTENSION) }
    end

    def self.warn_erb_is_opt_in(skipped)
      templates = skipped.count { _1.end_with?(FileLoader::ERB_EXTENSION) }
      warn(Rainbow("⚠️  WARNING: nothing was checked - #{templates} changed ERB template(s) were skipped " \
                   'because view coverage is opt-in. Check them with ' \
                   "--include-files '*.rb,*.rake,*.ru,Rakefile,*.erb' and enable_coverage(:eval) in SimpleCov.start.")
             .yellow)
    end

    def self.warn_if_erb_has_no_coverage(report)
      templates = report.erb_files_without_coverage
      return if templates.empty?

      warn(Rainbow("⚠️  WARNING: skipped #{templates.size} ERB template(s) - the coverage report has no " \
                   'ERB coverage. Add enable_coverage(:eval) to SimpleCov.start to check them.').yellow)
    end

    def self.build_formatter(flagged, validation_error, opts)
      if opts.formatter == 'json'
        Undercover::JsonFormatter.new(flagged, validation_error)
      else
        Undercover::Formatter.new(flagged, validation_error)
      end
    end

    def self.syntax_version(version)
      return unless version

      Imagen.parser_version = version
    end

    # --git-dir is resolved against the working directory, and the repository it points
    # at determines the project root. Everything else is derived from there.
    def self.changeset(opts)
      Undercover::Changeset.new(opts.git_dir, opts.compare, commits_only: opts.commits_only)
    end
  end
end
