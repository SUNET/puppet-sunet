# frozen_string_literal: true

# dnsLookup.rb
# does a DNS lookup and returns an array of strings of the results

require 'resolv'

Puppet::Functions.create_function(:dns_lookup) do |args|
  result = Resolv.new.getaddresses(args[0])
  return result
end
