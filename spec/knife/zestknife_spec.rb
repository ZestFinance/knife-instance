require 'spec_helper'

describe ZestKnife do
  subject { described_class.new }

  before do
    subject.stub(:domain).and_return('internal.com.')
    subject.class.stub(:AWS_REGIONS).and_return(['some_region'])
  end

  describe "#fqdn" do
    it { subject.fqdn('').should == '' }
    it { subject.fqdn(nil).should == '' }
    it "provides a valid fqdn" do
      fqdn = subject.fqdn('d999')
      fqdn.should == 'd999.internal.com.'
    end
  end

  describe "#zone" do
    let(:our_zone)        { double('our dns zone',   :domain => "internal.com.") }
    let(:some_other_zone) { double('other dns zone', :domain => "zambocom.net.") }

    before(:each) do
      aws_double = double
      Zest::AWS.stub(:new).and_return(aws_double)
      dns_double = double
      aws_double.stub(:dns).and_return(dns_double)
      dns_double.stub(:zones).and_return([our_zone, some_other_zone])
    end

    its(:zone) { should == our_zone }
  end

  describe "#domain" do
    its(:domain) { should match(/[a-z]+\.[a-z]+\./) }
    it { subject.domain[-1].should == '.' }
  end

  describe "#errors?" do
    it "should be true when there are any errors" do
      subject.errors << "Hello"
      subject.errors?.should be_true
    end

    it "should be false when there are no errors" do
      subject.errors?.should be_false
    end
  end

  describe "#setup_config" do
    it "should find env var and add to Chef::Config" do
      ENV["FOO"] = "bar"
      subject.setup_config(['FOO'])
      Chef::Config[:knife]['FOO'].should == "bar"
    end

    it "should prefer Chef::Config[:knife] options over ENV options" do
      ENV["foo"] = "bar"
      subject.setup_config(["foo"])
      Chef::Config[:knife]["foo"].should == "bar"

      Chef::Config[:knife]["foo"] = 2
      ENV["foo"] = "bar"
      subject.setup_config(["foo"])
      Chef::Config[:knife]["foo"].should == 2
    end
  end

  describe "#validate!" do
    before do
      subject.ui.stub(:error)
    end

    it "should add validation errors to error list" do
      lambda { subject.validate!([:foo]) }.should raise_error SystemExit
      subject.errors.should have(1).error
    end

    it "should report existing errors" do
      subject.errors << "Hello"
      lambda { subject.validate!([]) }.should raise_error SystemExit
      subject.errors.should have(1).error
    end
  end

  describe "#errors" do
    it "should not be assignable" do
      lambda { subject.errors = ['some-new-errors'] }.should raise_error
    end

    it "should be appendable" do
      subject.errors.should respond_to :<<
      subject.errors << "Hello"
      subject.errors[0].should == "Hello"
    end
  end

  describe "#find_r53" do
    let(:r53_cname_record) do
      double('Fog::DNS::AWS::Record',
           :class => 'Fog::DNS::AWS::Record',
           :name => "d999.internal.com.",
           :type => "CNAME",
           :value => "127-1-1-1.compute-1.amazonaws.com")
    end

    before do
      Fog::DNS.stub(:new) { double('fog dns client',
                                 :zones => [double('fake dns zone',
                                                 :records => r53_records,
                                                 :domain => "internal.com.")])}
    end

    context "instance exists" do
      let(:r53_records) { [r53_cname_record] }
      it { subject.find_r53('d999').should == [ r53_cname_record ] }
    end

    context "there is no such instance" do
      let(:r53_records) { double('Fake records', :select => [], :get => nil) }
      it { subject.find_r53('d999').should == [] }
    end
  end

  describe "#find_ec2" do
    let(:ec2_servers) { [ec2_instance] }
    let(:ec2_instance) do
      double('Fog::Compute::AWS::Server',
           :class => 'Fog::Compute::AWS::Server',
           :id => 'my_ec2_instance',
           :tags => {'Name' => 'd999'})
    end

    before do
      Fog::Compute.stub(:new) { double('fog compute client', :servers => ec2_servers) }
    end

    context "instance exists" do
      let(:ec2_servers) { [ec2_instance] }
      it { subject.find_ec2('d999').should == [ ec2_instance ] }
    end

    context "there is no such instance" do
      let(:ec2_servers) { [] }
      it { subject.find_ec2('d999').should == [] }
    end
  end

  describe "#find_item" do
    let(:client) { double }

    context "when class can be loaded" do
      let(:remote_resource) { double }
      before { client.should_receive(:load).with('my-name').and_return remote_resource }
      it { subject.find_item(client, 'my-name').should == [remote_resource] }
    end

    context "when class cannot be loaded" do
      let(:exception) { Net::HTTPServerException.new "example.com", 1234 }
      before { client.should_receive(:load).with('my-name').and_raise exception }
      it { subject.find_item(client, 'my-name').should == [] }
    end
  end

  describe "#generate_hostname" do
    before { subject.instance_variable_set :@base_domain, 'example.com' }

    it "should generate a valid hostname" do
      subject.should_receive(:check_services).exactly(2).times.and_return([])
      subject.validate_hostname subject.generate_hostname("production")
      subject.errors?.should be_false
    end

    it "should fail if the hostname is taken" do
      subject.should_receive(:check_services).exactly(5).times.and_return(["fake_error"])
      subject.generate_hostname "production"
      subject.errors?.should be_true
    end
  end

  describe "#validate_hostname" do
    let(:hostname) { 'd123' }
    before { subject.should_receive(:check_services).and_return(existing_services) }

    context "there is no such a host" do
      let(:existing_services) { [] }

      it "is valid" do
        subject.validate_hostname hostname
        subject.errors?.should be_false
      end
    end

    context "when the same host already exists" do
      let(:existing_services) { [hostname] }

      it "is not valid" do
        subject.validate_hostname hostname
        subject.errors?.should be_true
      end
    end
  end

  describe '#random_hostname' do
    context 'environment is production' do
      let(:env) { 'production' }
      before { subject.stub(:base_domain).and_return('example.com') }

      context 'external domain is example.com' do
        it { subject.random_hostname(env).should =~ /^ep\d\d\d$/ }
      end
    end
  end
end
