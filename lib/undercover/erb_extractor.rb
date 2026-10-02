# frozen_string_literal: true

require 'erubi'

module Undercover
  # Extracts a Ruby string from an ERB template, preserving line positions so
  # the parser gem produces an AST whose line numbers map 1:1 back to the
  # original .erb file.
  #
  # Uses erubi (pure Ruby, no native extension). Because erubi emits buffer
  # appends for HTML between Ruby tags, a `case` and its first `when` must live
  # in the same ERB tag (e.g. `<% case x\n   when :a %>`); a `<% case %>`
  # immediately followed by a separate `<% when %>` tag produces invalid Ruby
  # and is reported as a syntax error by the caller.
  module ErbExtractor
    module_function

    def call(erb_source)
      Erubi::Engine.new(erb_source, trim: true).src
    end
  end
end
