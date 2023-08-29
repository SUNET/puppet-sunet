# frozen_string_literal: true

# This is a wrapped around the standard lookup() function to log warnings whenever
# the resulting value is 'NOT_SET_IN_HIERA'.
#
# We use that as default value in lots of places where we don't want a missing
# value to interrupt puppet completely (because it makes for a catch 22 problem
# in bootstrapping new machines).
Puppet::Functions.create_function(:safe_hiera) do
  def safe_hiera(*arguments)
    value = call_function('lookup', arguments[0].to_s, nil, nil, 'NOT_SET_IN_HIERA')
    if value == 'NOT_SET_IN_HIERA'
      warn("#{arguments[0]} not set in Hiera")
      return arguments[1] if arguments.size == 2
    end
    value
  end
end
