require 'spec_helper'

describe ZestKnife do

  describe '#random_hostname' do
    let(:zk_instance) { described_class.new }
    subject { zk_instance.random_hostname env }

    context 'environment is production' do
      let(:env) { 'production' }
      before { zk_instance.instance_variable_set :@base_domain, base_domain }

      context 'domain is example.com' do
        let(:base_domain) { 'example.com' }
        it { should =~ /^ep\d\d\d$/ }
      end
    end
  end
end
