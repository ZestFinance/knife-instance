# This class generates the ec2 user-data bootstrap script
module Zest
  class BootstrapGenerator
    CONFIG_FILE_TEMPLATE = File.expand_path('templates/boot.sh.erb', __FILE__)

    def initialize(validation_key_file, validation_client_name, chef_server_url, environment, run_list, hostname, color, base_domain, encrypted_databag_secret_file)
      @validation_client_name = validation_client_name
      @validation_key_file = validation_key_file
      @chef_server_url = chef_server_url
      @environment = environment
      @run_list = run_list
      @hostname = hostname
      @color = color
      @base_domain = base_domain
      @encrypted_databag_secret_file = encrypted_databag_secret_file
    end

    def first_boot
      {
        "run_list"          => @run_list,
        "assigned_hostname" => @hostname,
        "rails"             => {"cluster" => {"color" => @color}},
        "base_domain"       => @base_domain
      }.to_json
    end

    def validation_key
      File.read(@validation_key_file)
    end

    def encrypted_data_bag_secret
      File.read @encrypted_databag_secret_file
    end

    def generate
      template = File.read(CONFIG_FILE_TEMPLATE)
      Erubis::Eruby.new(template).evaluate(self)
    end

    def config_content
      <<-CONFIG
  require 'syslog-logger'
  Logger::Syslog.class_eval do
    attr_accessor :sync, :formatter
  end

  log_level              :info
  log_location           Logger::Syslog.new("chef-client")
  chef_server_url        "#{@chef_server_url}"
  validation_client_name "#{@validation_client_name}"
  node_name              "#{@hostname}"
  CONFIG
    end

    def start_chef
      "/usr/bin/chef-client -j /etc/chef/first-boot.json -E #{@environment}"
    end
  end
end
