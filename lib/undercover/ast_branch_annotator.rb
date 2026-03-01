# frozen_string_literal: true

module Undercover
  class AstBranchAnnotator
    def self.call(ast_node)
      new.annotate(ast_node)
    end

    # rubocop:disable Metrics/MethodLength,Metrics/AbcSize,Metrics/CyclomaticComplexity
    def annotate(ast_node, info = {})
      return info unless ast_node.is_a?(::Parser::AST::Node)

      case ast_node.type
      when :if
        annotate_if_node(ast_node, info)
      when :case
        ast_node.children.drop(1).each do |child|
          next unless child.is_a?(::Parser::AST::Node) && child.type == :when

          cond_src = expression_source(child.children.first)
          info[child.location.keyword.line] ||= cond_src ? "when #{cond_src}" : 'when'
        end
      when :and
        info[ast_node.location.line] ||= '&&'
      when :or
        info[ast_node.location.line] ||= '||'
      end

      ast_node.children.each { |c| annotate(c, info) }
      info
    end
    # rubocop:enable Metrics/MethodLength,Metrics/AbcSize,Metrics/CyclomaticComplexity

    private

    # rubocop:disable Metrics/AbcSize,Metrics/CyclomaticComplexity,Metrics/PerceivedComplexity
    def annotate_if_node(ast_node, info)
      loc = ast_node.location
      cond_src = expression_source(ast_node.children.first)
      if loc.respond_to?(:keyword)
        kw = loc.keyword
        info[kw.line] ||= cond_src ? "#{kw.source} #{cond_src}" : kw.source
        info[loc.else.line] ||= loc.else.source if loc.respond_to?(:else) && loc.else
      elsif loc.respond_to?(:question)
        info[loc.question.line] ||= cond_src ? "? #{cond_src}" : '?'
        info[loc.colon.line] ||= ':' if loc.respond_to?(:colon) && loc.colon
      end
    end
    # rubocop:enable Metrics/AbcSize,Metrics/CyclomaticComplexity,Metrics/PerceivedComplexity

    def expression_source(node)
      node&.location&.expression&.source # rubocop:disable Style/SafeNavigationChainLength
    end
  end
end
