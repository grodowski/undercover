# frozen_string_literal: true

# Extensions to Imagen for parsing ERB templates via herb's extract_ruby.
# herb produces a Ruby string with line positions preserved (newlines kept),
# which the parser gem can then parse into a proper AST with correct line numbers
# that map 1:1 back to the original ERB file.
#
# TODO: port these extensions upstream to the imagen gem

module Imagen
  module Node
    # Virtual file-level container node for an ERB template. Mirrors the role
    # that Root plays for Ruby files: ErbVisitor puts all parsed block nodes
    # as children of this node.
    class ErbFile < Base
      attr_reader :full_path

      def initialize(filepath, code_dir)
        super()
        @full_path = File.join(code_dir, filepath)
        @name = File.basename(filepath)
      end

      def build_from_ruby_source(ruby_source)
        ast = Imagen::AST::Parser.parse(ruby_source, full_path)
        Undercover::ErbVisitor.traverse(ast, self)
        self
      rescue ::Parser::SyntaxError => e
        warn "#{full_path}: ERB parsing failed (#{e.message})"
        self
      end

      def human_name = 'erb file'
      def first_line = nil
      def last_line  = nil
      def source     = nil
      def empty_def? = false
      def file_path  = full_path
    end

    # Represents a Ruby construct parsed from an ERB template (if, while, case,
    # do...end block). Overrides source_lines to read from the original ERB file
    # rather than the extracted Ruby source buffer.
    class ErbNode < Base
      def build_from_ast(ast_node)
        super
        tap { @name = node_name(ast_node) }
      end

      def human_name
        "#{ast_node.type} block"
      end

      def source_lines
        file = ast_node.location.expression.source_buffer.name
        return [] unless File.exist?(file)

        File.readlines(file, chomp: true)[first_line - 1, last_line - first_line + 1]
      end

      def empty_def?
        false
      end

      private

      def node_name(ast_node)
        return "block#{args_list(ast_node)}" if ast_node.type == :block

        ast_node.type.to_s
      end

      def args_list(ast_node)
        args_node = ast_node.children.find { |n| n.is_a?(::Parser::AST::Node) && n.type == :args }
        return unless args_node

        arg_names = args_node.children.map { |arg| arg.children[0] }
        return if arg_names.empty?

        " (#{arg_names.join(', ')})"
      end
    end
  end
end

module Undercover
  # Imagen::Visitor subclass that recognises ERB-relevant Ruby constructs
  # (if, while, case, do...end blocks) in addition to the standard Ruby ones.
  # Used when processing .erb files via herb's extract_ruby output.
  class ErbVisitor < Imagen::Visitor
    TYPES = Imagen::Visitor::TYPES.merge(
      block: Imagen::Node::ErbNode,
      if: Imagen::Node::ErbNode,
      while: Imagen::Node::ErbNode,
      case: Imagen::Node::ErbNode
    ).freeze

    def visit(ast_node, parent)
      klass = TYPES[ast_node.type] || return
      klass.new.build_from_ast(ast_node).tap { |node| parent.children << node }
    end

    def traverse(ast_node, parent)
      return unless ast_node.is_a?(::Parser::AST::Node)

      node = visit(ast_node, parent)

      ast_node.children.each_with_index do |child, i|
        # elsif is parsed as an :if node in the else-position (index 2) of a
        # parent :if node. Skip it to avoid reporting it as a separate node —
        # it is already covered by the outer if's line range.
        next if ast_node.type == :if && i == 2 &&
                child.is_a?(::Parser::AST::Node) && child.type == :if

        traverse(child, node || parent)
      end
    end
  end
end
