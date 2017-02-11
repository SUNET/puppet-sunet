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
    #one, two = args
    # if two.nil?
    if args.size == 1
      value = function_hiera([args[0], 'NOT_SET_IN_HIERA'])
    else
      value = function_hiera(args)
    end
    warning("#{args[0]} not set in Hiera") if value == 'NOT_SET_IN_HIERA' or value == args[1]
    return value
  end
end
