# frozen_string_literal: true

require 'undercover'
require 'rainbow'

module Undercover
  module CLI
    # TODO: Report calls >parser< for each file instead of
    # traversing the whole project at first!

    WARNINGS_TO_S = {
      stale_coverage: Rainbow('♻️  Coverage data is older than your' \
        'latest changes. Re-run tests to update').yellow,
      no_changes: Rainbow('✅ No reportable changes').green
    }.freeze

    # TODO: add executable in ./bin later
    # rubocop:disable Metrics/AbcSize, Metrics/MethodLength
    def self.run(args)
      opts = Undercover::Options.new.parse(args)
      report = Undercover::Report.new(
        opts.lcov,
        opts.path,
        git_dir: opts.git_dir,
        compare: opts.compare
      ).build

      error = report.validate(opts.lcov)
      if error
        puts(WARNINGS_TO_S[error])
        return 1
      end

      warnings = report.build_warnings
      puts Undercover::Formatter.new(warnings)
      warnings.any? ? 1 : 0
    end
    # rubocop:enable Metrics/AbcSize, Metrics/MethodLength
  end
end
