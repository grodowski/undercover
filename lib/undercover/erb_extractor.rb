# frozen_string_literal: true

require 'erubi'

module Undercover
  # Extracts a Ruby string from an ERB template, preserving line positions so
  # the parser gem produces an AST whose line numbers map 1:1 back to the
  # original .erb file.
  #
  # Uses erubi (pure Ruby, no native extension).
  module ErbExtractor
    # Mirrors ActionView's Erubi handler: `<%= helper do |x| %>` opens a block,
    # so it must not be wrapped in `( ... ).to_s` like other expressions.
    class Engine < ::Erubi::Engine
      BLOCK_EXPR = /((\s|\))do|\{)(\s*\|[^|]*\|)?\s*\Z/

      private

      def add_expression(indicator, code)
        return super unless BLOCK_EXPR.match?(code)

        src << " #{bufvar}.append= " << code
      end
    end

    module_function

    def call(erb_source)
      Engine.new(erb_source, trim: true).src
    end
  end
end
