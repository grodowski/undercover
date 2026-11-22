# frozen_string_literal: true

# Stdlib only, so `undercover upload` loads without rugged, prism or simplecov
require 'base64'
require 'json'
require 'net/http'
require 'optparse'
require 'uri'
require 'undercover/version'

module Undercover
  # `undercover upload`, the only undercover command that makes network calls. Sends a
  # coverage report to UndercoverCI. Options come from flags and the environment, never
  # from the project's .undercover file.
  class Upload # rubocop:disable Metrics/ClassLength
    DEFAULT_URL = 'https://undercover-ci.com/v1/coverage'
    DEFAULT_SIMPLECOV = 'coverage/coverage.json'
    USER_AGENT = "undercover/#{VERSION} (upload)".freeze
    SUPPORT = 'Visit https://undercover-ci.com/docs or get support at help@undercover-ci.com.'
    LCOV_DEPRECATION_NOTICE = '⚠️ LCOV uploads are deprecated and will stop working soon. Please migrate to ' \
                              'SimpleCov::Formatter::Undercover: https://undercover-ci.com/docs#reporting'

    Options = Struct.new(
      :commit, :lcov, :simplecov, :repo, :url, :cancel, :help,
      :pull_request, :pull_request_base_ref, :pull_request_head_ref
    ) do
      def valid?
        !commit.nil? && !repo.nil?
      end

      def pull_request_valid?
        pull_request.nil? || pull_request.match?(/\A\d+\z/)
      end
    end

    BANNER = <<~TEXT
      Usage: undercover upload [options]

      Uploads a coverage report to UndercoverCI (https://undercover-ci.com), which
      posts the results as a check on the commit or pull request. The repository
      needs the UndercoverCI GitHub App installed. This is the only command that
      makes network calls; .undercover doesn't apply to it.

      In GitHub Actions, run it without options:  bundle exec undercover upload

    TEXT

    attr_reader :exitcode, :options

    # Returns the exit code
    def self.run(args, env = ENV)
      new(args, env).run
    end

    def initialize(args = [], env = ENV)
      @env = env
      @exitcode = 0
      @options = Options.new
      @parser = build_parser
      @parser.parse(args)
      apply_defaults
    rescue OptionParser::ParseError => e
      error("#{e.message}\n#{@parser}")
    end

    def run
      if options.help
        puts @parser
      elsif exitcode.zero?
        options.cancel ? cancel : upload
      end
      exitcode
    end

    def upload
      return self unless sendable?

      unless options.pull_request_valid?
        error("--pull-request must be a number, got #{options.pull_request.inspect}")
        return self
      end

      puts LCOV_DEPRECATION_NOTICE if options.lcov
      data = read_coverage or return self

      request(Net::HTTP::Post, upload_body(data))
    end

    def cancel
      return self unless sendable?

      request(Net::HTTP::Delete, {repo: target_repo, sha: options.commit}.to_json)
    end

    private

    def upload_body(data)
      {
        repo: target_repo,
        sha: options.commit,
        file_base64: Base64.strict_encode64(data),
        file_type: options.lcov ? :lcov : :json,
        pull_request_number: options.pull_request,
        pull_request_base_ref: options.pull_request_base_ref,
        pull_request_head_ref: options.pull_request_head_ref
      }.compact.to_json
    end

    def build_parser
      OptionParser.new do |opts|
        opts.banner = BANNER
        report_options(opts)
        target_options(opts)
        pull_request_options(opts)
        check_options(opts)
        opts.on_tail('-h', '--help', 'Prints this help') { options.help = true }
      end
    end

    def report_options(opts)
      opts.on('--simplecov FILE',
              "Report from SimpleCov::Formatter::Undercover. Default: #{DEFAULT_SIMPLECOV}") do |v|
        options.simplecov = v
      end
    end

    def target_options(opts)
      opts.on('--repo REPO', 'Repository, e.g. org/repo. Default: $GITHUB_REPOSITORY') do |v|
        options.repo = v
      end
      opts.on('--commit SHA', 'Commit to check. Default: the pull request head, or $GITHUB_SHA') do |v|
        options.commit = v
      end
    end

    # optional arguments, so a CI template that expands to nothing (a push build) is not an error
    def pull_request_options(opts)
      opts.on('--pull-request [NUMBER]', 'Pull request number. Default: from the GitHub Actions event') do |v|
        options.pull_request = presence(v)
      end
      opts.on('--pull-request-base-ref [BRANCH]', 'Pull request target branch. Default: $GITHUB_BASE_REF') do |v|
        options.pull_request_base_ref = presence(v)
      end
      opts.on('--pull-request-head-ref [BRANCH]', 'Pull request branch. Default: $GITHUB_HEAD_REF') do |v|
        options.pull_request_head_ref = presence(v)
      end
    end

    def check_options(opts)
      opts.on('--cancel', 'Cancel the check for --commit instead of uploading') { options.cancel = true }
      opts.on('--url URL', "UndercoverCI endpoint. Default: #{DEFAULT_URL}") { options.url = URI(_1) }
      opts.on('--lcov FILE', 'LCOV report (deprecated)') { options.lcov = _1 }
    end

    # On GitHub Actions a pull_request build checks out a merge commit (GITHUB_SHA), but
    # the check belongs to the pull request head
    def apply_defaults # rubocop:disable Metrics/AbcSize
      options.repo = presence(options.repo) || presence(@env['GITHUB_REPOSITORY'])
      options.commit = presence(options.commit) || presence(github_event.dig('pull_request', 'head', 'sha')) ||
                       presence(@env['GITHUB_SHA'])
      options.simplecov ||= DEFAULT_SIMPLECOV
      options.url ||= URI(DEFAULT_URL)
      options.pull_request ||= detected_pull_request
      apply_pull_request_ref_defaults
    end

    # pull_request builds run on refs/pull/N/merge, pull_request_target builds only have the event
    def detected_pull_request
      @env['GITHUB_REF'].to_s[/\Arefs\/pull\/(\d+)\//, 1] || presence(github_event.dig('pull_request', 'number'))
    end

    # Only meaningful with a pull request number
    def apply_pull_request_ref_defaults
      unless options.pull_request
        options.pull_request_base_ref = options.pull_request_head_ref = nil
        return
      end

      options.pull_request_base_ref ||= presence(@env['GITHUB_BASE_REF'])
      options.pull_request_head_ref ||= presence(@env['GITHUB_HEAD_REF'])
    end

    def github_event
      @github_event ||= begin
        event = JSON.parse(File.read(@env.fetch('GITHUB_EVENT_PATH', '')))
        event.is_a?(Hash) ? event : {}
      rescue Errno::ENOENT, JSON::ParserError
        {}
      end
    end

    def presence(value)
      value = value.to_s.strip
      value.empty? ? nil : value
    end

    def sendable?
      return true if options.valid?

      error("--repo and --commit are required outside GitHub Actions\n#{@parser}")
      false
    end

    def read_coverage
      file = options.lcov || options.simplecov
      return error("#{file} not found, is that the correct path?") unless File.file?(file)

      data = File.read(file)
      return error("#{file} is an empty file, is that the correct path?") if data.empty?

      data
    end

    # A fork's own builds run the upstream workflow, so --repo still names the upstream repo
    def target_repo
      @target_repo ||= begin
        running_in = presence(@env['GITHUB_REPOSITORY'])
        if running_in && !running_in.casecmp?(options.repo) && running_in_fork?
          puts "Running in #{running_in}, uploading coverage there instead of #{options.repo}"
          running_in
        else
          options.repo
        end
      end
    end

    # A workflow can also check out another repo on purpose, only a fork's own builds switch
    def running_in_fork?
      github_event.dig('repository', 'fork') == true
    end

    def retargeted?
      target_repo != options.repo
    end

    def request(method, body)
      url = options.url
      req = method.new(url.path, 'Content-Type' => 'application/json', 'User-Agent' => USER_AGENT)
      req.body = body
      resp = Net::HTTP.start(url.hostname, url.port, use_ssl: url.instance_of?(URI::HTTPS)) do |http|
        http.request(req)
      end
      handle_response(resp)
      self
    end

    def handle_response(resp)
      case resp.code.to_i
      when 200..299
        puts("Done! #{resp.code}")
      when 404
        not_found(resp.body)
      else
        return notice(already_uploaded_message) if error_code(resp.body) == 'already_uploaded'

        error("Error #{resp.code}, #{resp.body}. #{SUPPORT}")
      end
    end

    # e.g. a workflow that runs on both push and pull_request uploads twice for the same commit
    def already_uploaded_message
      "Coverage for commit #{options.commit} was already uploaded by another build, skipping."
    end

    # A fork without UndercoverCI is expected, its owner may not use it. The repository
    # named with --repo should have it.
    def not_found(body)
      if error_code(body) == 'not_installed'
        if retargeted?
          return notice("UndercoverCI isn't set up for #{target_repo}, so coverage wasn't uploaded. " \
                        "It's free for public repos: https://undercover-ci.com")
        end

        return error("UndercoverCI isn't installed on #{target_repo}. " \
                     'Install the GitHub App: https://undercover-ci.com')
      end

      error("Error 404: does a check for commit #{options.commit} exist in #{target_repo}? #{SUPPORT}")
    end

    # shown on the run's summary page on GitHub Actions, not only in the job log
    def notice(message)
      puts @env['GITHUB_ACTIONS'] == 'true' ? "::notice title=UndercoverCI::#{message}" : message
    end

    def error(message)
      @exitcode = 1
      warn(message)
      nil
    end

    def error_code(body)
      parsed = JSON.parse(body.to_s)
      parsed['code'] if parsed.is_a?(Hash)
    rescue JSON::ParserError
      nil
    end
  end
end
