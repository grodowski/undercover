# frozen_string_literal: true

require 'prism'

module Undercover
  # Builds the Node tree of a Prism syntax tree
  class NodeVisitor < Prism::Visitor
    attr_reader :roots

    def initialize(file_path, source_lines)
      super()
      @file_path = file_path
      @source_lines = source_lines
      @roots = []
      @parents = []
    end

    def visit_class_node(node)
      add(:class, node.name.to_s, node, node.body) { super }
    end

    def visit_module_node(node)
      add(:module, node.name.to_s, node, node.body) { super }
    end

    def visit_def_node(node)
      add(node.receiver ? :class_method : :instance_method, node.name_loc.slice, node, node.body) { super }
    end

    def visit_call_node(node)
      visit_block_call(node) { super }
    end

    def visit_super_node(node)
      visit_block_call(node) { super }
    end

    def visit_forwarding_super_node(node)
      visit_block_call(node) { super }
    end

    def visit_lambda_node(node)
      add(:block, block_name(node.parameters), node, node.body) { super }
    end

    private

    def visit_block_call(node, &)
      block = node.block
      return yield unless block.is_a?(Prism::BlockNode)

      add(:block, block_name(block.parameters), node, block.body, &)
    end

    def add(kind, name, prism_node, body)
      new_node = build(kind, name, prism_node, empty: body.nil?)
      (@parents.last&.children || roots) << new_node
      @parents.push(new_node)
      yield
      @parents.pop
    end

    def build(kind, name, prism_node, empty:)
      Node.new(kind, name, prism_node, @file_path, @source_lines, empty:)
    end

    # Lists explicit parameters only: `it` and numbered parameter blocks are a plain "block"
    def block_name(parameters)
      names = parameters.is_a?(Prism::BlockParametersNode) ? parameter_names(parameters) : []
      names.empty? ? 'block' : "block (#{names.join(', ')})"
    end

    def parameter_names(block_parameters)
      [*ordered_parameters(block_parameters.parameters), *block_parameters.locals].map do |param|
        param.is_a?(Prism::MultiTargetNode) ? param.slice : (param.name if param.respond_to?(:name))
      end
    end

    def ordered_parameters(params)
      return [] unless params

      [*params.requireds, *params.optionals, params.rest, *params.posts, *params.keywords, params.keyword_rest,
       params.block].compact.grep_v(Prism::ImplicitRestNode)
    end
  end
end
