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

      option :availability_zone,
             :short => "-Z ZONE",
             :long => "--availability-zone ZONE",
             :description => "The Availability Zone"

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
    end
  end
end
