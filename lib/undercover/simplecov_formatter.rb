# frozen_string_literal: true

require 'simplecov_json_formatter'

module Undercover
  class ResultHashFormatterWithRoot < SimpleCovJSONFormatter::ResultHashFormatter
    def format
      super

      add_undercover_meta_fields
    end

    private

    def add_undercover_meta_fields
      formatted_result.tap do |result|
        result[:meta].merge!(simplecov_root: SimpleCov.root)
      end
    end

    # format_files uses relative path as keys, as opposed to the superclass method
    def format_files
      @result.files.each do |source_file|
        formatted_result[:coverage][source_file.project_filename] =
          format_source_file(source_file)
      end
    end
  end

  class UndercoverSimplecovFormatter < SimpleCov::Formatter::JSONFormatter
    def format_result(result)
      result_hash_formater = ResultHashFormatterWithRoot.new(result)
      result_hash_formater.format
    end
  end
end

module SimpleCov
  module Formatter
    Undercover = ::Undercover::UndercoverSimplecovFormatter
  end
end
