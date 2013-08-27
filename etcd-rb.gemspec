# encoding: utf-8

$: << File.expand_path('../lib', __FILE__)

require 'etcd/version'


Gem::Specification.new do |s|
  s.name          = 'etcd-rb'
  s.version       = Etcd::VERSION.dup
  s.authors       = ['Theo Hultberg']
  s.email         = ['theo@iconara.net']
  s.homepage      = 'http://github.com/iconara/etcd-rb'
  s.summary       = %q{}
  s.description   = %q{}
  s.license       = 'Apache License 2.0'
  
  s.files         = Dir['lib/**/*.rb', 'bin/*', 'README.md']
  s.test_files    = Dir['spec/**/*.rb']
  s.require_paths = %w(lib)
  s.bindir        = 'bin'

  s.add_dependency 'httpclient', '~> 2.3.0'
  s.add_dependency 'multi_json', '~> 1.7.0'

  s.platform = Gem::Platform::RUBY
  s.required_ruby_version = '>= 1.9.3'
end
