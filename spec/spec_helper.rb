$:.unshift File.expand_path '../lib', File.dirname(__FILE__)
ENV['aws_access_key_id']     = '12345'
ENV['aws_secret_access_key'] = '12345'
ENV['aws_ssh_key']           = 'some_key'
ENV['DATABAG_KEY_PATH']      = File.expand_path 'support/databag.key', File.dirname(__FILE__)

Bundler.require :default, :development
require_all 'lib/chef'
require_all 'lib/knife-instance'
require 'fog'

Fog.mock!

RSpec.configure do |config|
  config.after(:each) do
    Chef::Config[:environment] = nil
  end
end
