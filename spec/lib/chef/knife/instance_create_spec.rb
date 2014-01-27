require 'spec_helper'

describe Chef::Knife::InstanceCreate do
  let(:internal_domain) { 'internal.com.' }

  before do
    described_class::load_deps
    @instance = described_class.new
    @instance.merge_configs
    @instance.internal_domain = internal_domain
    #TODO: refactor
    @instance.class.stub(:AWS_REGIONS).and_return(['some_region'])
    @instance.config[:environment] = "development"
    @instance.config[:cluster_tag] = "purplish"
    @instance.config[:base_domain] = "example.com"
    @instance.config[:hostname]    = 'd999'

    @compute = double
    @dns = double
    @zone = double
    @records = double
    @record = double
    @servers = double
    @server = double

    @server_attribs = {
        :id => 'i-12345',
        :flavor_id => 'vanilla',
        :image_id => 'ami-12345',
        :availability_zone => 'available',
        :key_name => 'my_ssh_key',
        :groups => ['group1', 'group2'],
        :dns_name => 'dns.name.com',
        :ip_address => '1.1.1.1',
        :private_dns_name => 'ip-1-1-1-1.ec2.internal',
        :private_ip_address => '1.1.1.1',
        :public_ip_address => '8.8.8.8',
        :root_device_type => 'instance',
        :environment => 'development',
        :hostname => 'd999'
    }

    @server_attribs.each_pair do |attrib, value|
      @server.stub(attrib).and_return(value)
    end
  end

  describe "run" do
    before do
      Fog::Compute::AWS.stub(:new).and_return(@compute)
      @compute.stub(:servers)
      @compute.stub(:images).and_return(@images)
      @zone.stub(:domain).and_return(internal_domain)
      @instance.stub(:puts)
      @instance.ui.stub(:error)
      @instance.stub(:get_user_data)
      @instance.stub(:ami).and_return(double)
      Chef::Config[:knife][:hostname] = @server.hostname
      @instance.stub(:find_ec2).and_return([])
      @instance.stub(:find_item).and_return([])
      @instance.stub(:find_r53).and_return([])
    end

    it "creates an EC2 instance and bootstraps it" do
      @compute.should_receive(:servers).and_return(@servers)
      @servers.should_receive(:create).and_return(@server)
      @instance.run
    end

    it "waits for aws response and registers host with route 53" do
      @compute.should_receive(:servers).and_return(@servers)
      @servers.should_receive(:create).and_return(@server)
      @instance.config[:wait_for_it] = true
      @records.should_receive(:create).and_return(true)
      @zone.should_receive(:records).and_return(@records)
      @dns.should_receive(:zones).at_least(:once).and_return([@zone])
      Fog::DNS::AWS.should_receive(:new).and_return(@dns)
      @server.should_receive(:wait_for).and_return(true)
      @instance.run
    end

    describe "#validate!" do
      context "when there is ec2 host already" do
        it "should exit with errors" do
          @instance.should_receive(:find_ec2).and_return([double])
          @instance.setup_config
          @instance.config[:environment] = "development"
          @instance.hostname = 'd999'
          expect { @instance.validate! }.to raise_error SystemExit
          @instance.errors.should include "d999 in RSpec::Mocks::Mock already exists. Delete first."
        end
      end
    end

    describe "#create_server_def" do
      context "VPC specific parameters" do
        let(:subnet_id) { "subnet-123" }
        let(:security_group_ids) { ['sg-123', 'sg456'] }
        before do
          @instance.config[:security_group_ids] = security_group_ids
          @instance.config[:subnet_id]          = subnet_id
        end

        subject { @instance.create_server_def }
        its([:security_group_ids]) { should == security_group_ids }
        its([:subnet_id])          { should == subnet_id }
      end
    end
  end
end
