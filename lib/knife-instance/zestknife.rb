require 'chef/knife'

class ZestKnife < Chef::Knife
  def self.with_opts(*args)
    invalid_args = args.select {|arg| !OPTS.keys.include? arg }
    raise "Invalid option(s) passed to with_opts: #{invalid_args.join(", ")}" unless invalid_args.empty?

    args.each do |arg|
      option arg, OPTS[arg]
    end
  end

  class << self; attr_accessor :validated_opts end

  def self.with_validated_opts(*args)
    with_opts(*args)
    validates(*args)
  end

  def self.validates(*args)
    raise "Invalid argument(s) passed to validates: #{args - VALIDATORS.keys}" unless (args - VALIDATORS.keys).empty?
    self.validated_opts ||= []
    self.validated_opts.concat args
  end

  def setup_config(keys=[:aws_access_key_id, :aws_secret_access_key])
    keys.each do |k|
      Chef::Config[:knife][k] = ENV[k.to_s] if Chef::Config[:knife][k].nil? && ENV[k.to_s]
    end
  end

  def validate!(keys=[:aws_access_key_id, :aws_secret_access_key])
    keys.each do |k|
      if Chef::Config[:knife][k].nil? & config[k].nil?
        errors << "You did not provide a valid '#{k}' value."
      end
    end

    self.class.validated_opts.each do |opt|
      send VALIDATORS[opt]
    end if self.class.validated_opts

    if errors.each { |e| ui.error(e) }.any?
      exit 1
    end
  end

  def validate_env
  end

  def validate_domain
  end

  def validate_region
  end

  def validate_color
    unless @color
      errors << "You must provide a cluster_tag with the -t option"
    end
  end

  def validate_prod
  end

  OPTS = {
    :aws_access_key_id => {
      :short => "-A ID",
      :long => "--aws-access-key-id KEY",
      :description => "Your AWS Access Key ID",
      :proc => Proc.new { |key| Chef::Config[:knife][:aws_access_key_id] = key }
    },
    :aws_secret_access_key => {
      :short => "-K SECRET",
      :long => "--aws-secret-access-key SECRET",
      :description => "Your AWS API Secret Access Key",
      :proc => Proc.new { |key| Chef::Config[:knife][:aws_secret_access_key] = key }
    },
    :cluster_tag => {
      :short => "-t TAG",
      :long => "--cluster-tag TAG",
      :description => "Tag that identifies this node as part of the <TAG> cluster"
    },
    :environment => {
      :short => "-E CHEF_ENV",
      :long => "--environment CHEF_ENV",
      :description => "Chef environment"
    },
    :region => {
      :long => "--region REGION",
      :short => '-R REGION',
      :description => "Your AWS region",
      :default => "",
      :proc => Proc.new { |key| Chef::Config[:knife][:region] = key }
    },
    :encrypted_data_bag_secret => {
      :short => "-B FILE",
      :long => "--encrypted_data_bag_secret FILE",
      :description => "Path to the secret key to unlock encrypted chef data bags",
      :default => ENV["DATABG_KEY_PATH"] ? File.expand_path(ENV["DATABAG_KEY_PATH"]) : ""
    },
    :aws_ssh_key_id => {
      :short => "-S KEY",
      :long => "--aws-ssh-key KEY",
      :description => "AWS EC2 SSH Key Pair Name",
      :default => ""
    },
    :base_domain => {
      :long => "--base-domain DOMAIN",
      :description => "The domain to be used for this node.",
      :default => ""
    },
     :wait_for_it => {
      :short => "-W",
      :long => "--wait-for-it",
      :description => "Wait for EC2 to return extended details about the host and register DNS",
      :boolean => true,
      :default => false
    },
    :prod => {
      :long => "--prod",
      :description => "If the environment for your command is production, you must also pass this parameter.  This is to make it slightly harder to do something unintentionally to production."
    }
  }

  VALIDATORS = {
    :environment  => :validate_env,
    :base_domain  => :validate_domain,
    :cluster_tag  => :validate_color,
    :prod         => :validate_prod,
    :region       => :validate_region
  }
end
