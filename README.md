# undercover 👮‍♂️

**Like RuboCop but for code coverage**. Inspects files in a git diff and warns on changed methods, classes and blocks which need to be tested. Use it locally or as part of an automated build to shorten your code coverage feedback loop!

- Visit **[https://undercover-ci.com](https://undercover-ci.com)** to set up actionable GitHub code review checks, or use one of the [integrations](#code-review-integrations)
- Learn how to find untested code changes locally with the [CLI](#usage)

A sample output of `undercover` ran before a commit may look like this:

![screenshot warning](docs/screenshot_warnings.png)

And like this, given that specs were added:

![screenshot success](docs/screenshot_success.png)

[![Build Status](https://action-badges.now.sh/grodowski/undercover)](https://github.com/grodowski/undercover/actions)
[![Maintainability](https://api.codeclimate.com/v1/badges/b403feed68a18c072ec5/maintainability)](https://codeclimate.com/github/grodowski/undercover/maintainability)

## Installation

Add this line to your application's Gemfile:

```ruby
gem 'undercover'
```

And then execute:

    $ bundle

Or install it yourself as:

    $ gem install undercover

## Setting up required LCOV reporting

To make your specs or tests compatible with `undercover` by providing an LCOV report, please add `simplecov` and `simplecov-lcov` to your test setup.

```ruby
# Gemfile
group :test do
  gem 'simplecov'
  gem 'simplecov-lcov'
end

# the very top of spec_helper.rb
require 'simplecov'
require 'simplecov-lcov'
SimpleCov::Formatter::LcovFormatter.config.report_with_single_file = true
SimpleCov.formatter = SimpleCov::Formatter::LcovFormatter
SimpleCov.start do
  add_filter(/^\/spec\//) # For RSpec
  add_filter(/^\/test\//) # For Minitest
  enable_coverage(:branch) # Report branch coverage to trigger branch-level undercover warnings
end

require 'undercover'

# ...
```

Then run your test suite once through to generate the initial `coverage/lcov/*.lcov` file before you can run the `undercover` command

## Usage

Invoked with no arguments, Undercover will flag all untested methods and classes from the current diff:

```sh
undercover
```

Use the `-c --compare ref` flag to specify a git ref (commit hash, branch name, tag) to compare against. **This is a recommended usage for CI/CD build environments**, as `undercover` will `exit 1` if there are any warnings.

```sh
undercover --compare origin/master
```

Check out `docs/` for CI configuration examples:
- [Travis CI](docs/travis.yml)
- [CircleCI - simple](docs/circleci_config.yml)
- [CircleCI - advanced](docs/circleci_advanced.yml)
- [Semaphore](docs/semaphore.yml)
- [Codeship](docs/codeship.md)

Merging coverage results ([sample gist](https://gist.github.com/grodowski/9744ff91034dce8df20c2a8210409fb0)) is required for parallel tests before processing with `undercover`.

## Code review integrations

A few options exist to provide automated comments from `undercover` in Pull Request reviews, which is the most streamlined way to add Undercover to your development workflow.

- [UndercoverCI](https://undercover-ci.com) - `undercover` Pull Request feedback delivered natively with GitHub Checks
- [pronto-undercover](https://github.com/grodowski/pronto-undercover)
- [danger-undercover](https://github.com/nimblehq/danger-undercover)
- [undercover-checkstyle](https://github.com/aki77/undercover-checkstyle)

## Configuration

### CLI Options

Options can be passed when running the command from the command line:

```sh
undercover -h
Usage: undercover [options]
    -l, --lcov path                  LCOV report file path
    -p, --path path                  Project directory
    -g, --git-dir dir                Override `.git` with a custom directory
    -c, --compare ref                Generate coverage warnings for all changes after `ref`
    -h, --help                       Prints this help
        --version                    Show version
```

### Configuration File

A configuration file named `.undercover` can be created at the top level of a project's directory containing the same set of options for the CLI.
Example file:

```sh
-l path/to/different.lcov
-c origin/master
```

The options set in the file can be overriden by passing arguments when invoking the executable.

Options assume that the program is run from the top level of the project directory.

## Why?

I wanted to create a tool to help others and myself ensure that tests are written for all the recent code changes. This should be useful for any ruby project, but especially those large or legacy codebases that lack testing (and we can't or don't want to invest in full test coverage).

The goal was to provide automated warnings, that are:
- relevant, so scoped to the actual code changes
- timely, so we don't end up writing tests long after the implementation
- actionable, so we can fix them before the code is committed or reaches production

For more background, please [read the blog post](https://medium.com/futuredev/stop-shipping-untested-ruby-code-with-undercover-1edc963be4a6).

## Development

After checking out the repo, run `bundle` to install dependencies. Then, run `rake` to run the tests and RuboCop. You can also run `pry -r 'undercover'` for an interactive prompt that will allow you to experiment.

To install this gem onto your local machine, run `bundle exec rake install`. To release a new version, update the version number in `version.rb`, and then run `bundle exec rake release`, which will create a git tag for the version, push git commits and tags, and push the `.gem` file to [rubygems.org](https://rubygems.org).

## Contributing

Bug reports and pull requests are welcome on GitHub at https://github.com/grodowski/undercover.

## License

The gem is available as open source under the terms of the [MIT License](https://opensource.org/licenses/MIT).
