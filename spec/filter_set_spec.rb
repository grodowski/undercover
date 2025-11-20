# frozen_string_literal: true

require 'spec_helper'
require 'undercover/filter_set'

describe Undercover::FilterSet do
  let(:allow_filters) { ['*.rb'] }
  let(:reject_filters) { ['*_spec.rb'] }
  let(:simplecov_filters) { [{file: 'app/lib/filtered_file.rb'}] }

  subject(:filter_set) { described_class.new(allow_filters, reject_filters, simplecov_filters) }

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
      let(:simplecov_filters) { [] }

      it 'behaves like the original FilterSet' do
        expect(filter_set.include?('app/models/user.rb')).to be true
        expect(filter_set.include?('app/models/user_spec.rb')).to be false
        expect(filter_set.include?('app/assets/style.css')).to be false
      end
    end

    context 'with complex glob patterns' do
      let(:allow_filters) { ['*.rb', '*.rake', 'Rakefile'] }
      let(:reject_filters) { ['test/*', 'spec/*'] }
      let(:simplecov_filters) { [{file: 'lib/migrations/20230101_create_users.rb'}] }

      it 'correctly applies all filters' do
        expect(filter_set.include?('app/models/user.rb')).to be true
        expect(filter_set.include?('Rakefile')).to be true
        expect(filter_set.include?('test/user_test.rb')).to be false
        expect(filter_set.include?('spec/user_spec.rb')).to be false
        expect(filter_set.include?('lib/migrations/20230101_create_users.rb')).to be false
      end
    end

    context 'with string and regex filters' do
      let(:simplecov_filters) do
        [
          {'string' => 'spec/'},
          {'regex' => '\/test\/'},
          {'file' => 'custom_ignored.rb'},
        ]
      end

      it 'correctly evaluates string filters' do
        expect(filter_set.include?('spec/user_spec.rb')).to be false
        expect(filter_set.include?('app/spec/helper.rb')).to be false
      end

      it 'correctly evaluates regex filters' do
        expect(filter_set.include?('app/test/unit_test.rb')).to be false
        expect(filter_set.include?('lib/test/integration_test.rb')).to be false
      end

      it 'correctly evaluates file filters' do
        expect(filter_set.include?('custom_ignored.rb')).to be false
      end

      it 'allows files not matching any filter' do
        expect(filter_set.include?('app/models/user.rb')).to be true
      end

      it 'handles file filter that does not match' do
        expect(filter_set.include?('different_file.rb')).to be true
      end

      it 'handles file filter that returns false when filepath does not match exactly' do
        file_filter_set = described_class.new(['*.rb'], [], [{file: 'exact_match.rb'}])
        expect(file_filter_set.include?('different_file.rb')).to be true
        expect(file_filter_set.include?('exact_match.rb')).to be false
      end

      it 'explicitly tests file filter branch where comparison returns false' do
        test_filter_set = described_class.new(['*.rb'], [], [{file: 'specific_file.rb'}])
        expect(test_filter_set.include?('other_file.rb')).to be true
      end

      it 'tests the false branch of file filter comparison within any loop' do
        multi_filter_set = described_class.new(['*.rb'], [], [
                                                 {file: 'will_not_match.rb'},
                                                 {string: 'also_will_not_match'},
                                               ])
        expect(multi_filter_set.include?('some_other_file.rb')).to be true
      end

      it 'specifically tests file filter false return in isolation' do
        isolated_filter_set = described_class.new(['*.rb'], [], [{file: 'exact_name.rb'}])
        expect(isolated_filter_set.include?('totally_different.rb')).to be true
        expect(isolated_filter_set.include?('exact_name.rb')).to be false
      end

      it 'forces file filter false evaluation by using non-matching filename' do
        force_false_set = described_class.new(['*.rb'], [], [{file: 'specific_file.rb'}])
        expect(force_false_set.include?('different_file.rb')).to be true
      end

      it 'tests the elsif branch condition itself with falsy file value' do
        falsy_filter_set = described_class.new(['*.rb'], [], [
                                                 {file: nil},
                                                 {file: ''},
                                                 {string: 'will_not_match'},
                                               ])
        expect(falsy_filter_set.include?('any_file.rb')).to be true
      end
    end

    context 'with Rails profile regex filters using leading slash' do
      let(:simplecov_filters) do
        # the "rails" profile creates these by default, as generated with:
        # require "simplecov"
        # require "undercover/simplecov_formatter"
        # SimpleCov.formatter = SimpleCov::Formatter::Undercover
        # SimpleCov.collate(Dir['./.resultset-test-*.json'], 'rails')
        [
          {'regex' => '^/db/'},
          {'regex' => '^/config/'},
          {'string' => '/spec/'},
        ]
      end

      it 'matches files without leading slash' do
        expect(filter_set.include?('db/migrate/20250101_create_users.rb')).to be false
        expect(filter_set.include?('config/initializers/setup.rb')).to be false
        expect(filter_set.include?('spec/controllers/foo_controller_test.rb')).to be false
      end

      it 'allows files not matching the regex patterns' do
        expect(filter_set.include?('app/models/user.rb')).to be true
      end
    end
  end
end
