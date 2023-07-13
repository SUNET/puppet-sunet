# frozen_string_literal: true

module Puppet
  module Parser
    # This is a wrapped around the standard lookup() function to log warnings whenever
    # the resulting value is 'NOT_SET_IN_HIERA'.
    #
    # We use that as default value in lots of places where we don't want a missing
    # value to interrupt puppet completely (because it makes for a catch 22 problem
    # in bootstrapping new machines).
    module Functions
      newfunction(:safe_hiera, type: :rvalue) do |args|
        # Puppet 3.7
        value = if Facter.value(:puppetversion).start_with? '3.7.'
                  function_hiera([args[0], 'NOT_SET_IN_HIERA'])
                else
                  # Puppet >= 3.8
                  call_function('lookup', [args[0], Puppet::Pops::Types::PDataType, Nil, 'NOT_SET_IN_HIERA'])
                end
        if value == 'NOT_SET_IN_HIERA'
          warning("#{args[0]} not set in Hiera")
          return args[1] if args.size == 2
        end
        return value
      end
    end
  end
end
