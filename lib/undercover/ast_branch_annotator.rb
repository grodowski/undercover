# frozen_string_literal: true

module Undercover
  class AstBranchAnnotator
    def self.call(ast_node)
      new.annotate(ast_node)
    end

    # rubocop:disable Metrics/MethodLength,Metrics/AbcSize
    def annotate(ast_node, info = {})
      return info unless ast_node.is_a?(::Parser::AST::Node)

      case ast_node.type
      when :if
        annotate_if_node(ast_node, info)
      when :case
        ast_node.children.drop(1).each do |child|
          next unless child.is_a?(::Parser::AST::Node) && child.type == :when

          cond_src = expression_source(child.children.first)
          info[child.location.keyword.line] ||= "when #{cond_src}"
        end
      end

      ast_node.children.each { |c| annotate(c, info) }
      info
    end
    # rubocop:enable Metrics/MethodLength,Metrics/AbcSize

    private

    def annotate_if_node(ast_node, info) # rubocop:disable Metrics/MethodLength,Metrics/AbcSize
      loc = ast_node.location
      cond_src = expression_source(ast_node.children.first)
      case loc
      when Parser::Source::Map::Condition
        kw = loc.keyword
        info[kw.line] ||= "#{kw.source} #{cond_src}"
        info[loc.else.line] ||= 'else' if loc.else&.source == 'else'
      when Parser::Source::Map::Ternary
        info[loc.question.line] ||= "? #{cond_src}"
        info[loc.colon.line] ||= ':'
      end
    end

    def expression_source(node)
      node.location.expression.source
    end
  end
end
