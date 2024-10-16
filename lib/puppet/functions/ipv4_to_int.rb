# frozen_string_literal: true


# Convert a single IPv4 address to an int

require 'ipaddr'

Puppet::Functions.create_function(:ipv4_to_int) do
  def ipv4_to_int(*arguments)
    IPAddr.new(arguments[0]).to_i
  end
end
