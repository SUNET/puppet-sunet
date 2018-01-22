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
      if args.size == 1
        value = function_hiera([args[0], 'NOT_SET_IN_HIERA'])
      else
        value = function_hiera(args)
      end
    else
      # Puppet >= 3.8 and Puppet 4.x
      if args.size == 1
        value = call_function('hiera', [args[0], 'NOT_SET_IN_HIERA'])
      else
        value = call_function('hiera', args)
      end
    end
    warning("#{args[0]} not set in Hiera") if value == 'NOT_SET_IN_HIERA' or value == args[1]
    return value
  end
end
