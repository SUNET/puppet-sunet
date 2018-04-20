#
# This is a wrapped around the standard hiera() function to log warnings whenever
# the resulting value is 'NOT_SET_IN_HIERA'.
#
# We use that as default value in lots of places where we don't want a missing
# value to interrupt puppet completely (because it makes for a moment 22 problem
# in bootstrapping new machines).
#
module Puppet::Parser::Functions
  newfunction(:safe_hiera, :type => :rvalue) do |args|

    # Puppet 3.7
    if Facter.value(:puppetversion).start_with? '3.7.'
      value = function_hiera([args[0], 'NOT_SET_IN_HIERA'])
    else
      # Puppet >= 3.8 and Puppet 4.x
      value = call_function('hiera', [args[0], 'NOT_SET_IN_HIERA'])
    end
    if value == 'NOT_SET_IN_HIERA'
      warning("#{args[0]} not set in Hiera")
      if args.size == 2
        return args[1]
      end
    end
    return value
  end
end
