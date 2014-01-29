require "knife-instance/zestknife"

class Chef
  class Knife
    class InstanceCreate < ::ZestKnife
      banner "knife instance create (options)"

      deps do
        require 'fog'
        require 'fog/aws/models/dns/record'
        require 'readline'
        require 'chef/json_compat'
        require 'chef/node'
        require 'chef/api_client'
      end

      attr_accessor :hostname

      with_opts :aws_ssh_key_id, :encrypted_data_bag_secret, :wait_for_it
      with_validated_opts :cluster_tag, :environment, :base_domain, :region

      option :flavor,
             :short => "-f FLAVOR",
             :long => "--flavor FLAVOR",
             :description => "The flavor of server (m1.small, m1.medium, etc)",
             :default => "m1.small"

      option :image,
             :short => "-I IMAGE",
             :long => "--image IMAGE",
             :description => "The AMI for the server"

      option :iam_role,
             :long => "--iam-role IAM_ROLE",
             :description => "Assign a node to an IAM Role. Set to 'default_role' by default",
             :default => 'default_role'

      option :security_groups,
             :short => "-G X,Y,Z",
             :long => "--groups X,Y,Z",
             :description => "The security groups for this server"

      option :security_group_ids,
             :short => "-g X,Y,Z",
             :long => "--security-group-ids X,Y,Z",
             :description => "The security group ids for this server; required when using VPC",
             :proc => Proc.new { |security_group_ids| security_group_ids.split(',') }

      option :availability_zone,
             :short => "-Z ZONE",
             :long => "--availability-zone ZONE",
             :description => "The Availability Zone"

      option :subnet_id,
             :short => "-s SUBNET-ID",
             :long => "--subnet SUBNET-ID",
             :description => "create node in this Virtual Private Cloud Subnet ID (implies VPC mode)",
             :proc => Proc.new { |key| Chef::Config[:knife][:subnet_id] = key }

      option :hostname,
             :short => "-h NAME",
             :long => "--node-name NAME",
             :description => "The Chef node name for your new node"

      option :run_list,
             :short => "-r RUN_LIST",
             :long => "--run-list RUN_LIST",
             :description => "(Required) Comma separated list of roles/recipes to apply",
             :default => ["role[base]"],
             :proc => lambda { |o| o.split(/[\s,]+/) }

      option :show_server_options,
             :short => "-D",
             :long => "--server-dry-run",
             :description => "Show the options used to create the server and exit before running",
             :boolean => true,
             :default => false

      def run
        $stdout.sync = true
        setup_config

        @environment = config[:environment]
        @base_domain = config[:base_domain]
        @hostname    = config[:hostname] || generate_hostname(@environment)
        @color       = config[:cluster_tag]
        @region      = config[:region]

        validate!

        get_user_data

        if config[:show_server_options]
          details = create_server_def
          ui.info(
              ui.color("Creating server with options\n", :bold) +
                  ui.color(JSON.pretty_generate(details.reject { |k, v| k == :user_data }), :blue) +
                  ui.color("\nWith user script\n", :bold) +
                  ui.color(details[:user_data], :cyan)
          )
          exit 0
        end

        server = ZestKnife.aws_for_region(@region).compute.servers.create(create_server_def)

        msg_pair("Zest Hostname", fqdn(hostname))
        msg_pair("Environment", @environment)
        msg_pair("Run List", config[:run_list].join(', '))
        msg_pair("Instance ID", server.id)
        msg_pair("Flavor", server.flavor_id)
        msg_pair("Image", server.image_id)
        msg_pair("Region", @region)
        msg_pair("Availability Zone", server.availability_zone)
        msg_pair("Security Groups", server.groups.join(", "))
        msg_pair("SSH Key", server.key_name)

        return unless config[:wait_for_it]

        print "\n#{ui.color("Waiting for server", :magenta)}"

        # wait for it to be ready to do stuff
        server.wait_for { print "."; ready? }

        puts "\n"
        msg_pair("Public DNS Name", server.dns_name)
        msg_pair("Public IP Address", server.public_ip_address)
        msg_pair("Private DNS Name", server.private_dns_name)
        msg_pair("Private IP Address", server.private_ip_address)
        msg_pair("Instance ID", server.id)
        msg_pair("Flavor", server.flavor_id)
        msg_pair("Image", server.image_id)
        msg_pair("Region", @region)
        msg_pair("Availability Zone", server.availability_zone)
        msg_pair("Security Groups", server.groups.join(", "))
        msg_pair("SSH Key", server.key_name)
        msg_pair("Root Device Type", server.root_device_type)

        zone.records.create(:name => fqdn(hostname), :type => 'A', :value => server.private_ip_address, :ttl => 300)

        server
      end

      def self.new_with_defaults environment, region, color, base_domain, opts
        new.tap do |ic|
          ic.config[:environment]               = environment
          ic.config[:cluster_tag]               = color
          ic.config[:region]                    = region
          ic.config[:base_domain]               = base_domain
          ic.config[:aws_ssh_key_id]            = opts[:aws_ssh_key_id]
          ic.config[:aws_access_key_id]         = opts[:aws_access_key_id]
          ic.config[:aws_secret_access_key]     = opts[:aws_secret_access_key]
          ic.config[:availability_zone]         = opts[:availability_zone]
          ic.config[:encrypted_data_bag_secret] = opts[:encrypted_data_bag_secret]
          ic.config[:wait_for_it]               = opts[:wait_for_it]
          ic.config[:image]                     = opts[:image]
          ic.config[:subnet_id]                 = opts[:subnet_id]
        end
      end

      def create_server_def
        server_def = {
            :image_id           => image,
            :groups             => config[:security_groups],
            :security_group_ids => config[:security_group_ids],
            :flavor_id          => config[:flavor],
            :key_name           => config[:aws_ssh_key_id],
            :availability_zone  => availability_zone,
            :subnet_id          => config[:subnet_id],
            :tags => {
                'Name'        => hostname,
                'environment' => @environment
            },
            :user_data                 => config[:without_user_data] ? "" : get_user_data,
            :iam_instance_profile_name => config[:iam_role]
        }
        server_def[:associate_public_ip] = true if vpc_mode?

        server_def
      end

      def vpc_mode?
        config[:subnet_id]
      end

      def image
        config[:image]
      end

      def availability_zone
        config[:availability_zone]
      end

      def ami
        @ami ||= ZestKnife.aws_for_region(@region).compute.images.get(image)
      end

      def validate!
        unless File.exists?(config[:encrypted_data_bag_secret])
          errors << "Could not find encrypted data bag secret. Tried #{config[:encrypted_data_bag_secret]}"
        end

        if ami.nil?
          errors << "You have not provided a valid image. Tried to find '#{image}'."
        end

        validate_hostname hostname

        super([:aws_access_key_id, :aws_secret_access_key,
               :flavor, :aws_ssh_key_id, :run_list])
      end

      def get_user_data
        generator = Zest::BootstrapGenerator.new(Chef::Config[:validation_key], Chef::Config[:validation_client_name], Chef::Config[:chef_server_url], @environment, config[:run_list], hostname, @color, @base_domain, config[:encrypted_data_bag_secret], domain)
        generator.generate
      end
    end
  end
end
