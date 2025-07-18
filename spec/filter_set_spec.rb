# frozen_string_literal: true

require 'spec_helper'
require 'undercover/filter_set'

describe Undercover::FilterSet do
  let(:allow_filters) { ['*.rb'] }
  let(:reject_filters) { ['*_spec.rb'] }
  let(:simplecov_ignored_files) { ['app/lib/filtered_file.rb'] }

  subject(:filter_set) { described_class.new(allow_filters, reject_filters, simplecov_ignored_files) }

  describe '#include?' do
    context 'when file is in SimpleCov ignored files' do
      it 'returns false regardless of other filters' do
        expect(filter_set.include?('app/lib/filtered_file.rb')).to be false
      end
    end

    context 'when file is not in SimpleCov ignored files' do
      it 'returns true for files matching allow filters and not matching reject filters' do
        expect(filter_set.include?('app/models/user.rb')).to be true
      end

      it 'returns false for files matching reject filters' do
        expect(filter_set.include?('app/models/user_spec.rb')).to be false
      end

      it 'returns false for files not matching allow filters' do
        expect(filter_set.include?('app/assets/style.css')).to be false
      end
    end

    context 'with empty SimpleCov ignored files' do
      let(:simplecov_ignored_files) { [] }

      it 'behaves like the original FilterSet' do
        expect(filter_set.include?('app/models/user.rb')).to be true
        expect(filter_set.include?('app/models/user_spec.rb')).to be false
        expect(filter_set.include?('app/assets/style.css')).to be false
      end
    end

    context 'with complex glob patterns' do
      let(:allow_filters) { ['*.rb', '*.rake', 'Rakefile'] }
      let(:reject_filters) { ['test/*', 'spec/*'] }
      let(:simplecov_ignored_files) { ['lib/migrations/20230101_create_users.rb'] }

      it 'correctly applies all filters' do
        expect(filter_set.include?('app/models/user.rb')).to be true
        expect(filter_set.include?('Rakefile')).to be true
        expect(filter_set.include?('test/user_test.rb')).to be false
        expect(filter_set.include?('spec/user_spec.rb')).to be false
        expect(filter_set.include?('lib/migrations/20230101_create_users.rb')).to be false
      end
    end
  end
end
