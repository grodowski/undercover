# frozen_string_literal: true

module Undercover
  # Parses a changed file into Undercover::Result nodes. ERB templates go through
  # ErbExtractor first, which turns a template into Ruby with line positions preserved
  # so the parser can place nodes back onto the original template's line numbers.
  #
  # Expects the host to provide #code_dir, #coverage_adapter and #loaded_files.
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
      full_path = File.join(code_dir, filepath)
      return unless File.exist?(full_path)

      ruby_source = Undercover::ErbExtractor.call(File.read(full_path))
      erb_file = Imagen::Node::ErbFile.new(filepath, code_dir)
                                      .build_from_ruby_source(ruby_source)
      return if erb_file.children.empty?

      loaded_files[key] = erb_file
                          .find_all(->(node) { !node.is_a?(Imagen::Node::ErbFile) })
                          .map { |node| Result.new(node, coverage_adapter, filepath) }
    rescue StandardError => e
      warn "#{filepath}: ERB parsing failed (#{e.message})"
    end
    # rubocop:enable Metrics/AbcSize, Metrics/MethodLength

    def load_ruby_file(key, filepath)
      root_ast = Imagen::Node::Root.new.build_from_file(File.join(code_dir, filepath))
      return if root_ast.children.empty?

      loaded_files[key] = root_ast
                          .find_all(->(node) { !node.is_a?(Imagen::Node::Root) })
                          .map { |node| Result.new(node, coverage_adapter, filepath) }
    end
  end
end
