# frozen_string_literal: true

module Undercover
  # A Ruby construct parsed from an ERB template (if, unless, while, until, case, block)
  class ErbNode < Node
    KINDS = %i[block if unless while until case].freeze

    # ErbExtractor keeps the template's line numbers, so nodes print the template's own lines.
    # partial_script allows a top-level yield, as in a layout.
    def self.parse(template, file_path)
      Node.parse(ErbExtractor.call(template), file_path, visitor_class: ErbVisitor,
                                                         source_lines: template.lines.map(&:chomp),
                                                         partial_script: true)
    end

    def human_name
      "#{kind} block"
    end
  end
end
