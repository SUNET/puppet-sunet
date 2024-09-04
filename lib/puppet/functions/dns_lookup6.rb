# frozen_string_literal: true

# dnsLookup.rb
# does a DNS lookup and returns an array of strings of the results

require 'resolv'

Puppet::Functions.create_function(:dns_lookup6) do
  def dns_lookup6(*arguments)
    Resolv.new.getaddresses(arguments[0],Resolv::DNS::Resource::IN::AAAA)
  end
end
