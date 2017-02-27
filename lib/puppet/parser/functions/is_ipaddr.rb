#
# Check if the provided value(s) is an IPv4/IPv6/either address.
#
# Puppet used to have validate_ and is_ functions for IPv4 and IPv6, but they
# deprecated them without providing functioning replacements (for Puppet 3.7).
#
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

    if not addr.instance_of? Array
      err("First argument to is_ipaddr is not a string or array: #{addr}")
      return false
    end

    if args.size == 2 and ipver.instance_of? != Integer
      err("Seconf argument to is_ipaddr is not an integer: #{ipver}")
      return false
    end

    addr.each do |this|
      if ipver == 4 and not this.ipv4?
        debug("#{addr} is not an IPv4 address")
        return False
      end

      if ipver == 6 and not this.ipv6?
        debug("#{addr} is not an IPv6 address")
        return False
      end

      if not this.ip?
        debug("#{addr} is not an IPv4/IPv6 address")
        return False
      end
    end

    return True
  end
end
