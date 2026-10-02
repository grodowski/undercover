# frozen_string_literal: true

require 'spec_helper'

describe Undercover::CoverageRoot do
  # spec/fixtures/monorepo holds app/ (with main.rb, lib/foo_lib.rb) and admin_app/
  let(:git_root) { File.expand_path('fixtures/monorepo', __dir__) }
  let(:keys) { %w[main.rb lib/foo_lib.rb] }

  describe '.derive' do
    it 'returns NONE when coverage was recorded at the repository root' do
      expect(described_class.derive(git_root, git_root, %w[README.md])).to eq('')
    end

    it 'derives the coverage root from SimpleCov.root' do
      expect(described_class.derive(git_root, "#{git_root}/app", keys)).to eq('app')
    end

    it 'derives it from a SimpleCov.root recorded on another machine' do
      # undercover-ci analyses an uploaded report against its own clone, so the absolute
      # path never matches; only the tail is meaningful
      expect(described_class.derive(git_root, '/home/semaphore/monorepo/app', keys)).to eq('app')
      expect(described_class.derive(git_root, '/build/x/y/app', keys)).to eq('app')
    end

    it 'prefers the longest tail that exists' do
      expect(described_class.derive(git_root, '/ci/app/lib', %w[foo_lib.rb])).to eq('app/lib')
    end

    it 'returns NONE when the directory does not hold the covered files' do
      # admin_app exists, but none of the covered files are in it
      expect(described_class.derive(git_root, '/ci/admin_app', keys)).to eq('')
    end

    it 'returns NONE when no tail of SimpleCov.root exists in the repository' do
      expect(described_class.derive(git_root, '/ci/nowhere/at/all', keys)).to eq('')
    end

    it 'returns NONE without a SimpleCov.root, as with LCOV reports' do
      expect(described_class.derive(git_root, nil, keys)).to eq('')
      expect(described_class.derive(git_root, '', keys)).to eq('')
    end

    it 'returns NONE without a git root' do
      expect(described_class.derive(nil, "#{git_root}/app", keys)).to eq('')
    end

    it 'accepts a candidate without keys to check against' do
      expect(described_class.derive(git_root, '/ci/app', nil)).to eq('app')
      expect(described_class.derive(git_root, '/ci/app', [])).to eq('app')
    end
  end

  describe '.strip' do
    it 'removes the coverage root prefix' do
      expect(described_class.strip('app/lib/foo.rb', 'app')).to eq('lib/foo.rb')
    end

    it 'is a no-op without a root' do
      expect(described_class.strip('lib/foo.rb', '')).to eq('lib/foo.rb')
      expect(described_class.strip('lib/foo.rb', nil)).to eq('lib/foo.rb')
    end

    it 'does not strip a partial directory match' do
      expect(described_class.strip('application/foo.rb', 'app')).to eq('application/foo.rb')
    end
  end

  describe '.under?' do
    it 'detects paths inside and outside the coverage root' do
      expect(described_class.under?('app/main.rb', 'app')).to be(true)
      expect(described_class.under?('admin_app/app.rb', 'app')).to be(false)
      expect(described_class.under?('application/x.rb', 'app')).to be(false)
    end

    it 'treats everything as in scope without a root' do
      expect(described_class.under?('anything.rb', '')).to be(true)
    end
  end
end
