# frozen_string_literal: true

module Undercover
  # Parses a changed file into Undercover::Result nodes. ERB templates go through
  # ErbExtractor first, which turns a template into Ruby with line positions preserved
  # so the parser can place nodes back onto the original template's line numbers.
  #
  # Expects the host to provide #code_dir, #coverage_adapter, #loaded_files and #erb_parse_failures.
  module FileLoader
    ERB_EXTENSION = '.erb'

    def load_and_parse_file(filepath)
      key = filepath.gsub(/^\.\//, '')
      return if loaded_files[key]

      if filepath.end_with?(ERB_EXTENSION)
        load_erb_file(key, filepath)
      else
        load_ruby_file(key, filepath)
      end
    end

    private

    # rubocop:disable Metrics/AbcSize, Metrics/MethodLength
    def load_erb_file(key, filepath)
      return unless coverage_adapter.erb_coverage?
      return if erb_parse_failures.include?(key)

      full_path = File.join(code_dir, filepath)
      return unless File.exist?(full_path)

      ruby_source = Undercover::ErbExtractor.call(File.read(full_path))
      erb_file = Imagen::Node::ErbFile.new(filepath, code_dir)
                                      .build_from_ruby_source(ruby_source)
      return erb_parse_failed(key, erb_file.parse_error) if erb_file.parse_error
      return if erb_file.children.empty?

      loaded_files[key] = build_results(erb_file.find_all(->(node) { !node.is_a?(Imagen::Node::ErbFile) }), filepath)
    rescue StandardError => e
      erb_parse_failed(key, e.message)
    end
    # rubocop:enable Metrics/AbcSize, Metrics/MethodLength

    def erb_parse_failed(key, message)
      erb_parse_failures << key
      warn "#{key}: ERB parsing failed (#{message})"
    end

    def load_ruby_file(key, filepath)
      root_ast = Imagen::Node::Root.new.build_from_file(File.join(code_dir, filepath))
      return if root_ast.children.empty?

      loaded_files[key] = build_results(root_ast.find_all(->(node) { !node.is_a?(Imagen::Node::Root) }), filepath)
    end

    # Indexes the file's coverage once for all of its nodes
    def build_results(nodes, filepath)
      index = CoverageIndex.new(coverage_adapter.coverage(filepath))
      nodes.map { |node| Result.new(node, coverage_adapter, filepath, coverage_index: index) }
    end
  end
end
