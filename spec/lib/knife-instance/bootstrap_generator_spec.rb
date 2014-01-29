require 'spec_helper'

describe Zest::BootstrapGenerator do
  let(:bootstrap_generator) { described_class.new(validation_key_file, validation_client_name, chef_server_url, encrypted_databag_secret_file, attr) }
  let(:validation_key_file) { "/path/to/validation_key" }
  let(:validation_client_name) { "this is the validation client name" }
  let(:chef_server_url) { "this is the url for the chef server" }
  let(:encrypted_databag_secret_file) { "/path/to/encrypted_databag_secret_file" }
  let(:attr) { {
    :environment => environment,
    :run_list => run_list,
    :hostname => hostname,
    :color => color,
    :base_domain => base_domain,
    :domain => domain
  } }
  let(:environment) { "this is an environment" }
  let(:run_list) { "this is a run list" }
  let(:hostname) { "this is a hostname" }
  let(:color) { "this is a color" }
  let(:base_domain) { "this is a base domain" }
  let(:domain) { "this is a domain" }

  describe "#first_boot" do
    subject { JSON.parse(bootstrap_generator.first_boot) }

    it "defines the run list" do
      subject["run_list"].should == "this is a run list"
    end

    it "assigns the hostname" do
      subject["assigned_hostname"].should == "this is a hostname"
    end

    it "contains the cluster color" do
      subject["rails"]["cluster"]["color"].should == "this is a color"
    end

    it "contains the base domain" do
      subject["base_domain"].should == "this is a base domain"
    end

    it "contains the domain" do
      subject["domain"].should == "this is a domain"
    end
  end

  describe "#validation_key" do
    subject { bootstrap_generator.validation_key }

    before :each do
      File.stub(:read).with(validation_key_file).and_return("this is a validation key")
    end

    it "returns the contents of the validation key file" do
      subject.should == "this is a validation key"
    end
  end

  describe "#encrypted_data_bag_secret" do
    subject { bootstrap_generator.encrypted_data_bag_secret }

    before :each do
      File.stub(:read).with(encrypted_databag_secret_file).and_return("this is a encrypted data bag secret")
    end

    it "returns the contents of the validation key file" do
      subject.should == "this is a encrypted data bag secret"
    end
  end

  describe "#config_content" do
    subject { bootstrap_generator.config_content }

    it "generates the correct config" do
      subject.should == <<-CONFIG
  require 'syslog-logger'
  Logger::Syslog.class_eval do
    attr_accessor :sync, :formatter
  end

  log_level              :info
  log_location           Logger::Syslog.new("chef-client")
  chef_server_url        "this is the url for the chef server"
  validation_client_name "this is the validation client name"
  node_name              "this is a hostname"
  CONFIG
    end
  end

  describe "#start_chef" do
    subject { bootstrap_generator.start_chef }

    it "generates the correct chef start command" do
      subject.should == "/usr/bin/chef-client -j /etc/chef/first-boot.json -E this is an environment"
    end
  end
end
