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
    # (If, While, Case, ErbBlock) as children of this node.
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

    # Base class for nodes parsed from ERB-extracted Ruby.
    # Overrides source_lines to read from the original ERB file rather than
    # the extracted Ruby source buffer, so pretty_print shows real ERB content.
    class ErbNode < Base
      def source_lines
        file = ast_node.location.expression.source_buffer.name
        return [] unless File.exist?(file)

        File.readlines(file, chomp: true)[first_line - 1, last_line - first_line + 1]
      end

      def empty_def?
        false
      end
    end

    # Handles do...end blocks in ERB (e.g. <% @users.each do |u| %>)
    class ErbBlock < ErbNode
      def build_from_ast(ast_node)
        super
        tap { @name = ['block', args_list].compact.join(' ') }
      end

      def human_name
        'block'
      end

      private

      def args_list
        args_node = ast_node.children.find { |n| n.is_a?(::Parser::AST::Node) && n.type == :args }
        return unless args_node

        arg_names = args_node.children.map { |arg| arg.children[0] }
        return if arg_names.empty?

        "(#{arg_names.join(', ')})"
      end
    end

    class If < ErbNode
      def build_from_ast(ast_node)
        super
        tap { @name = 'if' }
      end

      def human_name
        'if block'
      end
    end

    class While < ErbNode
      def build_from_ast(ast_node)
        super
        tap { @name = 'while' }
      end

      def human_name
        'while block'
      end
    end

    class Case < ErbNode
      def build_from_ast(ast_node)
        super
        tap { @name = 'case' }
      end

      def human_name
        'case block'
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
      block: Imagen::Node::ErbBlock,
      if: Imagen::Node::If,
      while: Imagen::Node::While,
      case: Imagen::Node::Case
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
