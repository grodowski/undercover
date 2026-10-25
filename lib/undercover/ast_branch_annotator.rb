# frozen_string_literal: true

require 'prism'

module Undercover
  # Labels the lines where Ruby's branch coverage starts a branch (if, unless, ternary,
  # case/when) with the source of their condition
  class AstBranchAnnotator < Prism::Visitor
    def self.call(prism_node)
      return {} unless prism_node.is_a?(Prism::Node)

      new.tap { prism_node.accept(_1) }.info
    end

    attr_reader :info

    def initialize
      super
      @info = {}
    end

    def visit_if_node(node)
      if node.if_keyword_loc
        label(node.if_keyword_loc, "#{node.if_keyword_loc.slice} #{node.predicate.slice}")
        label_else(node.subsequent)
      else
        label(node.then_keyword_loc, "? #{node.predicate.slice}")
        label(node.subsequent.else_keyword_loc, ':')
      end
      super
    end

    def visit_unless_node(node)
      label(node.keyword_loc, "unless #{node.predicate.slice}")
      label_else(node.else_clause)
      super
    end

    def visit_when_node(node)
      label(node.keyword_loc, "when #{node.conditions.first.slice}")
      super
    end

    # A guard (`in x if y`) is not a branch of its own
    def visit_in_node(node)
      guard = node.pattern
      return super unless guard.is_a?(Prism::IfNode) || guard.is_a?(Prism::UnlessNode)

      [guard.statements, guard.predicate, node.statements].compact.each { _1.accept(self) }
    end

    private

    def label(location, text)
      info[location.start_line] ||= text
    end

    def label_else(branch)
      label(branch.else_keyword_loc, 'else') if branch.is_a?(Prism::ElseNode)
    end
  end
end
