# frozen_string_literal: true

# dnsLookup.rb
# does a DNS lookup and returns an array of strings of the results

require 'resolv'

Puppet::Functions.create_function(:dns_lookup) do
  def dns_lookup(*arguments)
    Resolv.new.getaddresses(arguments[0])
  end
end
