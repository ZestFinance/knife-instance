# knife-instance [![Code Climate](https://codeclimate.com/github/ZestFinance/knife-instance.png)](https://codeclimate.com/github/ZestFinance/knife-instance)

Manage EC2 instances with Chef from the command line

## Installation

Add this line to your application's Gemfile:

    gem 'knife-instance'

And then execute:

    $ bundle

Or install it yourself as:

    $ gem install knife-instance

## Configuration

Add this to your environment ~/.bashrc or ~/.zshrc

```shell
export aws_access_key_id='Put your key here'
export aws_secret_access_key='Put your key here'
```

## Usage

```shell
bundle exec knife instance create -E development \
  --image 'my_ec2-image' \
  -t myclustertag \
  --group=my_security_group
```

## Contributing

1. Fork it ( http://github.com/ZestFinance/knife-instance/fork )
2. Create your feature branch (`git checkout -b my-new-feature`)
3. Commit your changes (`git commit -am 'Add some feature'`)
4. Push to the branch (`git push origin my-new-feature`)
5. Create new Pull Request

## Credits
Inspired by [knife-ec2 gem](https://github.com/opscode/knife-ec2)
