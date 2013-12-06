require 'chef/knife'

class ZestKnife < Chef::Knife
  def errors
    @errors ||= []
  end

  def errors?
    !errors.empty?
  end

  def self.aws_for_region(region)
    Zest::AWS.new(Chef::Config[:knife][:aws_access_key_id], Chef::Config[:knife][:aws_secret_access_key], region)
  end

  def self.AWS_REGIONS
    []
  end

  def self.in_all_aws_regions
    self.AWS_REGIONS.each do |region|
      yield self.aws_for_region(region)
    end
  end

  def find_item(klass, name)
    begin
      object = klass.load(name)
      return [object]
    rescue Net::HTTPServerException
      return []
    end
  end

  def find_ec2(name)
    nodes = {}
    self.class.in_all_aws_regions do |zest_aws|
      nodes = nodes.merge(zest_aws.compute.servers.group_by { |s| s.tags["Name"] })
    end
    nodes[name].nil? ? [] : nodes[name]
  end

  def find_r53 name
    in_zone = zone_from_name(name)
    if in_zone.nil?
      in_zone = zone
      name = fqdn(name)
    end
    name = "#{name}." unless name[-1] == "."
    recs = in_zone.records.select {|r| r.name == name }.to_a
    recs.empty? ? [in_zone.records.get(name)].compact : recs
  end

  def zone
    unless @zone
      self.class.in_all_aws_regions do |zest_aws|
        @zone ||= zest_aws.dns.zones.detect { |z| z.domain.downcase == domain }
      end
      raise "Could not find DNS zone" unless @zone
    end

    @zone
  end

  def zone_from_name dns_name
    name, tld = dns_name.split(".")[-2..-1]
    if name && tld
      dns_domain = "#{name}.#{tld}"
      zone = nil

      self.class.in_all_aws_regions do |zest_aws|
        zone1 = zest_aws.dns.zones.select {|x| x.domain =~ /^#{dns_domain}/ }.first
        zone = zone1 if zone1
      end

      zone
    end
  end

  def fqdn(name)
    return '' if name.nil? || name.empty?
    "#{name}.#{domain}"
  end

  def domain
    ""
  end

  def generate_hostname env
    name = nil

    5.times do |i|
      name = random_hostname env
      break if check_services(name).empty?

      name = nil
      srand # re-seed rand so we don't get stuck in a sequence
    end

    errors << "Unable to find available hostname in 5 tries" if name.nil?
    name
  end

  def validate_hostname hostname
    errors << "hostname can't be blank" and return if (hostname.nil? || hostname.empty?)
    check_services(hostname).each do |service|
      errors << "#{hostname} in #{service.class} already exists. Delete first."
    end

    errors << "hostname does not start with a valid prefix" unless hostname_starts_with_valid_prefix?(hostname)
    errors << "hostname is not valid prefix followed by numbers" unless hostname_is_alpha_followed_by_numbers?(hostname)
  end

  def check_services hostname
    find_item(Chef::Node, hostname) +
      find_item(Chef::ApiClient, hostname) +
      find_ec2(hostname) +
      find_r53(hostname)
  end

  def random_hostname env
    "#{domain_prefix}#{environment_prefix env}#{random_three_digit_number}"
  end

  def domain_prefix
    @base_domain.first
  end

  def environment_prefix env
    env.first
  end

  def random_three_digit_number
    sprintf("%03d", rand(1000))
  end

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
      :default => ENV['AWS_REGION'],
      :proc => Proc.new { |key| Chef::Config[:knife][:region] = key }
    },
    :encrypted_data_bag_secret => {
      :short => "-B FILE",
      :long => "--encrypted_data_bag_secret FILE",
      :description => "Path to the secret key to unlock encrypted chef data bags",
      :default => ENV["DATABAG_KEY_PATH"] ? File.expand_path(ENV["DATABAG_KEY_PATH"]) : ""
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
