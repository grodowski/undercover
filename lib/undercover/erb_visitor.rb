# frozen_string_literal: true

module Undercover
  # Also reports the control flow of ERB templates, where whole sections of markup sit in
  # an if or a loop. An if is one node with its elsif branches.
  class ErbVisitor < NodeVisitor
    def visit_if_node(node)
      add(:if, 'if', node, node.statements) { visit_if_branches(node) }
    end

    def visit_unless_node(node)
      add(:unless, 'unless', node, node.statements) { super }
    end

    def visit_while_node(node)
      add(:while, 'while', node, node.statements) { super }
    end

    def visit_until_node(node)
      add(:until, 'until', node, node.statements) { super }
    end

    def visit_case_node(node)
      add(:case, 'case', node, node.conditions) { super }
    end

    private

    def visit_if_branches(node)
      node.predicate.accept(self)
      node.statements&.accept(self)
      branch = node.subsequent
      branch.is_a?(Prism::IfNode) ? visit_if_branches(branch) : branch&.accept(self)
    end

    def build(kind, name, prism_node, empty:)
      return super unless ErbNode::KINDS.include?(kind)

      ErbNode.new(kind, name, prism_node, @file_path, @source_lines, empty:)
    end
  end
end
