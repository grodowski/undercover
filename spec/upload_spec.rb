# frozen_string_literal: true

require 'spec_helper'
require 'tempfile'
require 'undercover/upload'

describe Undercover::Upload do
  let(:requests) { [] }
  let(:connections) { [] }
  let(:simplecov) { 'spec/fixtures/nocov.json' }
  let(:lcov) { 'spec/fixtures/sample.lcov' }

  def build_upload(arg_str, env = {})
    described_class.new(arg_str.split, env)
  end

  def stub_response(code, body = '')
    response = instance_double(Net::HTTPResponse, code: code.to_s, body: body)
    http = instance_double(Net::HTTP)
    allow(http).to receive(:request) do |req|
      requests << req
      response
    end
    allow(Net::HTTP).to receive(:start) do |*args, **kwargs, &block|
      connections << [*args, kwargs]
      block.call(http)
    end
  end

  def stub_json_response(code, payload)
    stub_response(code, JSON.generate(payload))
  end

  def request
    expect(requests.size).to eq(1)
    requests.first
  end

  def uploaded_body
    JSON.parse(request.body)
  end

  def with_github_event(event)
    Tempfile.create(['event', '.json']) do |file|
      file.write(event.to_json)
      file.flush
      yield file.path
    end
  end

  it 'prints usage and exits 0 with --help' do
    expect(Net::HTTP).not_to receive(:start)
    expect { expect(described_class.run(%w[--help], {})).to eq(0) }
      .to output(a_string_including('Usage: undercover upload [options]', 'never does', '.undercover')).to_stdout
  end

  it 'exits 1 with usage on an unknown option' do
    expect { expect(described_class.run(%w[--include-files lib/**/*.rb], {})).to eq(1) }
      .to output(a_string_including('invalid option: --include-files', 'Usage: undercover upload')).to_stderr
  end

  it 'exits 1 and prints usage without --repo and --commit outside GitHub Actions' do
    expect(Net::HTTP).not_to receive(:start)
    expect { expect(described_class.run([], {})).to eq(1) }
      .to output(a_string_including('--repo and --commit are required', 'Usage: undercover upload')).to_stderr
  end

  it 'requires --repo and --commit to cancel' do
    expect { expect(described_class.run(%w[--cancel --repo alice/bob], {})).to eq(1) }
      .to output(a_string_including('--repo and --commit are required')).to_stderr
  end

  it 'uploads SimpleCov JSON coverage successfully' do
    stub_response(201)
    expect do
      expect(build_upload("--simplecov #{simplecov} --repo alice/bob --commit 1fffbb").run).to eq(0)
    end.to output("Done! 201\n").to_stdout

    expect(request).to be_a(Net::HTTP::Post)
    expect(request.path).to eq('/v1/coverage')
    expect(request['Content-Type']).to eq('application/json')
    expect(request.body).to eq(
      JSON.generate(
        repo: 'alice/bob', sha: '1fffbb', file_base64: Base64.strict_encode64(File.read(simplecov)), file_type: 'json'
      )
    )
    expect(connections).to eq([['undercover-ci.com', 443, {use_ssl: true}]])
  end

  it "sends undercover's version in the User-Agent" do
    stub_response(201)
    expect { build_upload("--simplecov #{simplecov} --repo alice/bob --commit 1fffbb").run }.to output.to_stdout

    expect(request['User-Agent']).to eq("undercover/#{Undercover::VERSION} (upload)")
  end

  it 'defaults --simplecov to coverage/coverage.json' do
    upload = build_upload('--repo alice/bob --commit 1fffbb')
    expect(upload.options.simplecov).to eq('coverage/coverage.json')
  end

  it 'uploads LCOV with a deprecation notice' do
    stub_response(201)
    expect do
      expect(build_upload("--lcov #{lcov} --repo alice/bob --commit 1fffbb").run).to eq(0)
    end.to output(a_string_including('LCOV uploads are deprecated', 'Done! 201')).to_stdout

    expect(uploaded_body).to include('file_type' => 'lcov', 'file_base64' => Base64.strict_encode64(File.read(lcov)))
  end

  it 'uploads to a custom --url with a port' do
    stub_response(201)
    expect do
      build_upload("--simplecov #{simplecov} --repo alice/bob --commit 1fffbb --url http://localhost:3000/v1/coverage")
        .run
    end.to output(a_string_including('Done! 201')).to_stdout

    expect(connections).to eq([['localhost', 3000, {use_ssl: false}]])
  end

  it 'exits 1 when the coverage report is missing' do
    expect(Net::HTTP).not_to receive(:start)
    expect { expect(build_upload('--simplecov missing.json --repo alice/bob --commit 1fffbb').run).to eq(1) }
      .to output(a_string_including('missing.json not found, is that the correct path?')).to_stderr
  end

  it 'exits 1 when the coverage report is empty' do
    Tempfile.create(['empty', '.json']) do |file|
      expect { expect(build_upload("--simplecov #{file.path} --repo alice/bob --commit 1fffbb").run).to eq(1) }
        .to output(a_string_including("#{file.path} is an empty file, is that the correct path?")).to_stderr
    end
  end

  it 'prints the server error message on error' do
    stub_json_response(422, 'error' => 'Too many coverage uploads')
    expect { expect(build_upload("--simplecov #{simplecov} --repo alice/bob --commit 1fffbb").run).to eq(1) }
      .to output(a_string_including('Error 422, {"error":"Too many coverage uploads"}', 'help@undercover-ci.com'))
      .to_stderr
  end

  it 'exits 1 on a 422 that is not JSON' do
    stub_response(422, '<html>Unprocessable</html>')
    expect { expect(build_upload("--simplecov #{simplecov} --repo alice/bob --commit 1fffbb").run).to eq(1) }
      .to output(a_string_including('Error 422, <html>Unprocessable</html>')).to_stderr
  end

  it 'handles a 404 when the check is not found' do
    stub_json_response(404, 'error' => 'record not found')
    expect { expect(build_upload("--simplecov #{simplecov} --repo alice/bob --commit 1fffbb").run).to eq(1) }
      .to output(a_string_including('Error 404: does a check for commit 1fffbb exist in alice/bob?')).to_stderr
  end

  it 'handles a 404 with a JSON body that is not an object' do
    stub_json_response(404, ['not_installed'])
    expect { expect(build_upload("--simplecov #{simplecov} --repo alice/bob --commit 1fffbb").run).to eq(1) }
      .to output(a_string_including('Error 404: does a check for commit 1fffbb exist in alice/bob?')).to_stderr
  end

  it "fails with install instructions when UndercoverCI isn't installed on --repo" do
    stub_json_response(404, 'error' => 'not installed', 'code' => 'not_installed')
    expect { expect(build_upload("--simplecov #{simplecov} --repo alice/bob --commit 1fffbb").run).to eq(1) }
      .to output(
        "UndercoverCI isn't installed on alice/bob. Install the GitHub App: https://undercover-ci.com\n"
      ).to_stderr
  end

  context 'when coverage for the commit was already uploaded' do
    before do
      stub_json_response(
        422, 'error' => 'Coverage for 1fffbb has already been uploaded to check 18.', 'code' => 'already_uploaded'
      )
    end

    let(:message) { 'Coverage for commit 1fffbb was already uploaded by another build, skipping.' }

    it 'prints a notice and exits 0' do
      expect { expect(build_upload("--simplecov #{simplecov} --repo alice/bob --commit 1fffbb").run).to eq(0) }
        .to output("#{message}\n").to_stdout
    end

    it 'prints a GitHub Actions notice annotation' do
      upload = build_upload("--simplecov #{simplecov} --repo alice/bob --commit 1fffbb", 'GITHUB_ACTIONS' => 'true')
      expect { upload.run }
        .to output("::notice title=UndercoverCI::#{message}\n").to_stdout
    end
  end

  it 'accepts --cancel to cancel a check' do
    stub_response(204)
    expect { expect(build_upload('--cancel --repo alice/bob --commit 1fffbb').run).to eq(0) }
      .to output("Done! 204\n").to_stdout

    expect(request).to be_a(Net::HTTP::Delete)
    expect(request.body).to eq(JSON.generate(repo: 'alice/bob', sha: '1fffbb'))
  end

  describe 'pull request options' do
    let(:args) { "--simplecov #{simplecov} --repo alice/bob --commit 1fffbb" }

    before { stub_response(201) }

    def upload(extra_args = '', env = {})
      expect { build_upload("#{args} #{extra_args}", env).run }.to output.to_stdout
      uploaded_body
    end

    it 'sends the pull request number when --pull-request is given' do
      expect(upload('--pull-request 42')).to include('pull_request_number' => '42')
    end

    it 'omits the pull request number when --pull-request expands to nothing' do
      expect(build_upload("--pull-request #{args}").options.pull_request).to be_nil
      expect(upload('--pull-request')).not_to have_key('pull_request_number')
    end

    it 'exits 1 when --pull-request is not a number' do
      expect { expect(build_upload("--pull-request b4c0n #{args}").run).to eq(1) }
        .to output(a_string_including('--pull-request must be a number')).to_stderr
      expect(requests).to be_empty
    end

    it 'sends --pull-request-base-ref and --pull-request-head-ref with the pull request number' do
      body = upload('--pull-request 42 --pull-request-base-ref release/1.x --pull-request-head-ref feature',
                    'GITHUB_BASE_REF' => 'main', 'GITHUB_HEAD_REF' => 'fix/typo')
      expect(body).to include('pull_request_base_ref' => 'release/1.x', 'pull_request_head_ref' => 'feature')
    end

    it 'defaults the refs to GITHUB_BASE_REF and GITHUB_HEAD_REF' do
      body = upload('--pull-request 42 --pull-request-base-ref', 'GITHUB_BASE_REF' => 'develop',
                                                                 'GITHUB_HEAD_REF' => 'fix/typo')
      expect(body).to include('pull_request_base_ref' => 'develop', 'pull_request_head_ref' => 'fix/typo')
    end

    it 'omits the refs without a pull request number' do
      body = upload('--pull-request-base-ref main', 'GITHUB_BASE_REF' => 'develop')
      expect(body.keys).not_to include('pull_request_number', 'pull_request_base_ref', 'pull_request_head_ref')
    end

    it 'omits the base ref when there is none' do
      expect(upload('--pull-request 42', 'GITHUB_BASE_REF' => '')).not_to have_key('pull_request_base_ref')
    end

    it 'detects the pull request on a GitHub Actions pull request build' do
      body = upload('', 'GITHUB_REF' => 'refs/pull/42/merge', 'GITHUB_BASE_REF' => 'develop')
      expect(body).to include('pull_request_number' => '42', 'pull_request_base_ref' => 'develop')
    end

    it 'detects the pull request from the event on a pull_request_target build' do
      with_github_event('pull_request' => {'number' => 42}) do |path|
        body = upload('', 'GITHUB_REF' => 'refs/heads/main', 'GITHUB_EVENT_PATH' => path)
        expect(body).to include('pull_request_number' => '42')
      end
    end

    it 'prefers an explicit --pull-request over the detected one' do
      expect(upload('--pull-request 7', 'GITHUB_REF' => 'refs/pull/42/merge'))
        .to include('pull_request_number' => '7')
    end

    it 'sends no pull request number on a push build' do
      body = upload('', 'GITHUB_REF' => 'refs/heads/main', 'GITHUB_BASE_REF' => '')
      expect(body.keys).not_to include('pull_request_number', 'pull_request_base_ref')
    end
  end

  describe 'GitHub Actions defaults' do
    let(:env) { {'GITHUB_REPOSITORY' => 'alice/bob', 'GITHUB_SHA' => 'merge123'} }

    before { stub_response(201) }

    def upload(arg_str, env)
      expect { expect(build_upload(arg_str, env).run).to eq(0) }.to output.to_stdout
      uploaded_body
    end

    it 'takes --repo from GITHUB_REPOSITORY and --commit from GITHUB_SHA' do
      expect(upload("--simplecov #{simplecov}", env)).to include('repo' => 'alice/bob', 'sha' => 'merge123')
    end

    it 'takes --commit from the pull request head, not the merge commit' do
      with_github_event('pull_request' => {'number' => 42, 'head' => {'sha' => 'head456'}}) do |path|
        body = upload("--simplecov #{simplecov}", env.merge('GITHUB_EVENT_PATH' => path))
        expect(body).to include('sha' => 'head456', 'pull_request_number' => '42')
      end
    end

    it 'prefers explicit --repo and --commit' do
      body = upload("--simplecov #{simplecov} --repo alice/other --commit 1fffbb", env)
      expect(body).to include('repo' => 'alice/other', 'sha' => '1fffbb')
    end

    it 'ignores an unreadable event file' do
      Tempfile.create(['event', '.json']) do |file|
        file.write('[not json')
        file.flush
        expect(upload("--simplecov #{simplecov}", env.merge('GITHUB_EVENT_PATH' => file.path)))
          .to include('sha' => 'merge123')
      end
    end

    it 'ignores an event that is not an object' do
      with_github_event([1]) do |path|
        expect(upload("--simplecov #{simplecov}", env.merge('GITHUB_EVENT_PATH' => path)))
          .to include('sha' => 'merge123')
      end
    end
  end

  describe 'fork retargeting' do
    let(:args) { "--simplecov #{simplecov} --repo alice/bob --commit 1fffbb" }

    it 'uploads to --repo from a workflow in another repository that is not a fork' do
      stub_response(201)
      with_github_event('repository' => {'fork' => false}) do |path|
        expect { build_upload(args, 'GITHUB_REPOSITORY' => 'alice/ci', 'GITHUB_EVENT_PATH' => path).run }
          .to output.to_stdout
      end
      expect(uploaded_body).to include('repo' => 'alice/bob')
    end

    it 'uploads to --repo without an event file to tell a fork apart' do
      stub_response(201)
      expect { build_upload(args, 'GITHUB_REPOSITORY' => 'alice/ci').run }.to output.to_stdout
      expect(uploaded_body).to include('repo' => 'alice/bob')
    end

    context "when running in a contributor's fork" do
      around do |example|
        with_github_event('repository' => {'fork' => true}) do |path|
          @env = {'GITHUB_REPOSITORY' => 'someone/bob-fork', 'GITHUB_EVENT_PATH' => path}
          example.run
        end
      end

      def upload(env = {})
        build_upload(args, @env.merge(env))
      end

      it 'uploads to the repository it runs in' do
        stub_response(201)
        expect { expect(upload.run).to eq(0) }
          .to output(a_string_including('Running in someone/bob-fork, uploading coverage there instead of alice/bob'))
          .to_stdout
        expect(uploaded_body).to include('repo' => 'someone/bob-fork')
      end

      it "prints a setup notice and succeeds when UndercoverCI isn't set up there" do
        stub_json_response(404, 'error' => 'not installed', 'code' => 'not_installed')
        expect { expect(upload.run).to eq(0) }
          .to output(
            a_string_including(
              "\nUndercoverCI isn't set up for someone/bob-fork, so coverage wasn't uploaded. " \
              "It's free for public repos: https://undercover-ci.com\n"
            )
          ).to_stdout
      end

      it 'shows the setup notice on the run summary on GitHub Actions' do
        stub_json_response(404, 'error' => 'not installed', 'code' => 'not_installed')
        expect { upload('GITHUB_ACTIONS' => 'true').run }
          .to output(a_string_including("::notice title=UndercoverCI::UndercoverCI isn't set up for someone/bob-fork"))
          .to_stdout
      end

      it 'fails on a 404 when UndercoverCI is installed there but has no check' do
        stub_json_response(404, 'error' => 'record not found')
        expect { expect(upload.run).to eq(1) }
          .to output(a_string_including('Error 404: does a check for commit 1fffbb exist in someone/bob-fork?'))
          .to_stderr
      end

      it "fails on a 404 that isn't from UndercoverCI" do
        stub_response(404, '<html>Not Found</html>')
        expect { expect(upload.run).to eq(1) }.to output(a_string_including('Error 404')).to_stderr
      end

      it 'cancels the check in the repository it runs in' do
        stub_response(204)
        expect { build_upload("#{args} --cancel", @env).run }.to output.to_stdout
        expect(JSON.parse(request.body)).to include('repo' => 'someone/bob-fork')
      end

      it 'uploads to --repo when only the case differs' do
        stub_response(201)
        expect { upload('GITHUB_REPOSITORY' => 'Alice/Bob').run }.to output.to_stdout
        expect(uploaded_body).to include('repo' => 'alice/bob')
      end
    end
  end
end
