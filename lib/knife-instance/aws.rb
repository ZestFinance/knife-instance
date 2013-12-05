module Zest
  class AWS
    attr_accessor :aws_access_key_id, :aws_secret_access_key, :region

    def initialize aws_access_key_id, aws_secret_access_key, region
      @aws_access_key_id, @aws_secret_access_key, @region = aws_access_key_id, aws_secret_access_key, region
    end

    def compute
      @compute ||= begin
        Fog::Compute.new(
          :provider => 'AWS',
          :aws_access_key_id => aws_access_key_id,
          :aws_secret_access_key => aws_secret_access_key,
          :region => region
        )
      end
    end

    def servers
      @servers ||= compute.servers
    end

    def dns
      @dns ||= begin
        Fog::DNS.new(
          :provider => 'AWS',
          :aws_access_key_id => aws_access_key_id,
          :aws_secret_access_key => aws_secret_access_key
        )
      end
    end
  end
end
