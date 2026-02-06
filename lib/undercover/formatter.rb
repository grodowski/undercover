# frozen_string_literal: true

module Undercover
  class Formatter
    WARNINGS_TO_S = {
      stale_coverage: Rainbow('🚨 WARNING: Coverage data is older than your ' \
                              'latest changes and results might be incomplete. ' \
                              'Re-run tests to update').yellow,
      no_changes: Rainbow('✅ No reportable changes').green
    }.freeze

    def initialize(results, validation_error = nil)
      @results = results
      @validation_error = validation_error
    end

    def to_s
      return WARNINGS_TO_S[@validation_error] if @validation_error

      return success unless @results.any?

      ([warnings_header] + formatted_warnings).join("\n")
    end

    def exit_code
      return 0 if @validation_error
      return 0 unless @results.any?

      1
    end

    private

    def formatted_warnings
      @results.map.with_index(1) do |res, idx|
        "🚨 #{idx}) node `#{res.node.name}` type: #{res.node.human_name},\n" +
          (' ' * pad_size) + "loc: #{res.file_path_with_lines}, " \
                             "coverage: #{res.coverage_f * 100}%\n" +
          res.pretty_print
      end
    end

    def success
      "#{Rainbow('undercover').bold.green}: ✅ No coverage " \
        'is missing in latest changes'
    end

    def warnings_header
      "#{Rainbow('undercover').bold.red}: " \
        '👮‍♂️ some methods have no test coverage! Please add specs for ' \
        'methods listed below'
    end

    def pad_size
      5 + (@results.size - 1).to_s.length
    end
  end
end
