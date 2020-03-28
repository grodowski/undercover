# frozen_string_literal: true

require 'undercover'
require 'rainbow'

module Undercover
  module CLI
    # TODO: Report calls >parser< for each file instead of
    # traversing the whole project at first!

    WARNINGS_TO_S = {
      stale_coverage: Rainbow('🚨 WARNING: Coverage data is older than your ' \
        'latest changes and results might be incomplete. ' \
        'Re-run tests to update').yellow,
      no_changes: Rainbow('✅ No reportable changes').green
    }.freeze
    def self.run(args)
      opts = Undercover::Options.new.parse(args)
      syntax_version(opts.syntax_version)

      run_report(opts)
    end
    # rubocop:enable

    def self.run_report(opts)
      report = Undercover::Report.new(changeset(opts), opts).build

      error = report.validate(opts.lcov)
      if error
        puts(WARNINGS_TO_S[error])
        return 0 if error == :no_changes
      end

      flagged = report.flagged_results
      puts Undercover::Formatter.new(flagged)
      flagged.any? ? 1 : 0
    end

    def self.syntax_version(version)
      return unless version

      Imagen.parser_version = version
    end

    def self.changeset(opts)
      git_dir = File.join(opts.path, opts.git_dir)
      Undercover::Changeset.new(git_dir, opts.compare)
    end
  end
end
