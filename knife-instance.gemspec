# coding: utf-8
lib = File.expand_path('../lib', __FILE__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require 'knife-instance/version'

Gem::Specification.new do |spec|
  spec.name          = "knife-instance"
  spec.version       = Knife::Instance::VERSION
  spec.authors       = ["Alexander Tamoykin", "Val Brodsky"]
  spec.email         = ["at@zestfinance.com", "vlb@zestfinance.com", "p@zestfinance.com"]
  spec.summary       = %q{Manage EC2 instances with Chef from the command line}
  spec.description   = %q{Manage EC2 instances with Chef from the command line}
  spec.homepage      = "https://github.com/ZestFinance/knife-instance"
  spec.license       = "MIT"

  spec.files         = `git ls-files`.split($/)
  spec.executables   = spec.files.grep(%r{^bin/}) { |f| File.basename(f) }
  spec.test_files    = spec.files.grep(%r{^(test|spec|features)/})
  spec.require_paths = ["lib"]

  spec.add_dependency 'chef', '>= 0.10.24'
  spec.add_dependency 'fog', '>= 1.9.0'
  spec.add_development_dependency "rake"
  spec.add_development_dependency "rspec"
  spec.add_development_dependency "require_all"
end
