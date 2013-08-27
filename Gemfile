source 'https://rubygems.org/'

gemspec

group :development do
  gem 'pry'
  gem 'travis'
  gem 'travis-lint'
  platforms :mri do
    gem 'yard'
    gem 'redcarpet'
  end
  platforms :mri_19 do
    gem 'perftools.rb'
  end
end

group :test do
  gem 'rspec'
  gem 'webmock'
  gem 'simplecov'
  gem 'coveralls'
end
