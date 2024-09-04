# frozen_string_literal: true

# dnsLookup.rb
# does a DNS lookup and returns an array of strings of the results

require 'resolv'

Puppet::Functions.create_function(:dns_lookup4) do
  def dns_lookup4(*arguments)
    Resolv.new.getaddresses(arguments[0],Resolv::DNS::Resource::IN::A)
  end
end
