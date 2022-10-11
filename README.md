# TypedSupport

**Note:** 

This gem is extracted from an old project which started life in early 2018., While the project still relies on this code
to a certain extent, it is slowing being removed and migrated to using `dry-rb` and I recommend you do too. 

Ie. I am releasing this for posterity and to help others who might be interested in poking around, **but not recommending
it for new projects.**

This gem provides a set of classes & modules that can be used to add runtime type checking support to 'attributes' 
on classes.

The gem also contains a set of classes which use these typed attributes to provide an ActiveModel like form model,
and a similar schema model used to validate and coerce data.

## Installation

Install the gem and add to the application's Gemfile by executing:

    $ bundle add typed_support

If bundler is not being used to manage dependencies, install the gem by executing:

    $ gem install typed_support

## Usage

TODO: Write usage instructions here

## Development

After checking out the repo, run `bin/setup` to install dependencies. Then, run `rake test` to run the tests. You can also run `bin/console` for an interactive prompt that will allow you to experiment.

To install this gem onto your local machine, run `bundle exec rake install`. To release a new version, update the version number in `version.rb`, and then run `bundle exec rake release`, which will create a git tag for the version, push git commits and the created tag, and push the `.gem` file to [rubygems.org](https://rubygems.org).

## Contributing

Bug reports and pull requests are welcome on GitHub at https://github.com/[USERNAME]/typed_support.

## License

The gem is available as open source under the terms of the [MIT License](https://opensource.org/licenses/MIT).
