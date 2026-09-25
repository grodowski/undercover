# frozen_string_literal: true

require 'spec_helper'

describe Undercover::CoverageRoot do
  describe '.derive' do
    it 'returns NONE when the coverage root is the repository root' do
      paths = %w[main.rb lib/foo.rb spec/foo_spec.rb]
      keys = %w[main.rb lib/foo.rb]
      expect(described_class.derive(paths, keys)).to eq('')
    end

    it 'derives a nested coverage root in a monorepo' do
      paths = %w[README.md admin_app/app.rb app/main.rb app/lib/foo.rb app/db/migrate/x.rb]
      keys = %w[main.rb lib/foo.rb]
      expect(described_class.derive(paths, keys)).to eq('app')
    end

    it 'derives a deeply nested coverage root' do
      paths = %w[apps/dash/main.rb apps/dash/lib/foo.rb apps/other/main.rb]
      keys = %w[main.rb lib/foo.rb]
      expect(described_class.derive(paths, keys)).to eq('apps/dash')
    end

    it 'returns NONE when no coverage key matches a repository path' do
      expect(described_class.derive(%w[a/b.rb], %w[totally/unrelated.rb])).to eq('')
    end

    it 'returns NONE when the prefix is ambiguous' do
      paths = %w[apps/one/main.rb apps/two/main.rb]
      expect(described_class.derive(paths, %w[main.rb])).to eq('')
    end

    it 'disambiguates using additional coverage keys' do
      paths = %w[apps/one/main.rb apps/two/main.rb apps/one/lib/foo.rb]
      expect(described_class.derive(paths, %w[main.rb lib/foo.rb])).to eq('apps/one')
    end

    it 'returns NONE for empty input' do
      expect(described_class.derive([], %w[main.rb])).to eq('')
      expect(described_class.derive(%w[main.rb], [])).to eq('')
      expect(described_class.derive(nil, nil)).to eq('')
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
