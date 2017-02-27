#
# Check if the provided value(s) is an IPv4/IPv6/either address.
#
# Puppet used to have validate_ and is_ functions for IPv4 and IPv6, but they
# deprecated them without providing functioning replacements (for Puppet 3.7).
#

require 'ipaddr'

module Puppet::Parser::Functions
  newfunction(:is_ipaddr, :type => :rvalue) do |args|
    if args.size < 1 or args.size > 2
      err("Invalid use of function is_ipaddr")
    end

    addr = args[0]
    ipver = args[1]

    if addr.instance_of? String
      addr = [addr]
    end

    if ! addr.instance_of? Array
      err("First argument to is_ipaddr is not a string or array: #{addr}")
      return false
    end

    if args.size == 2 and ! ipver.is_a? Integer
      err("Second argument to is_ipaddr is not an integer: #{ipver}")
      return false
    end

    addr.each do |this|
      this_addr = IPAddr.new(this) rescue false
      if ipver == 4 and ! this_addr.ipv4?
        debug("#{this} is not an IPv4 address")
        return false
      end

      if ipver == 6 and ! this_addr.ipv6?
        debug("#{this} is not an IPv6 address")
        return false
      end
    end

    debug("All inputs #{addr} found to be IP (#{ipver}) address(es).")
    return true
  end
end
