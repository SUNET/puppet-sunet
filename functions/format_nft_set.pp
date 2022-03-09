# Make a nftables { set }
#
# $prefix is probably 'ip saddr' or 'port'
# $arg is probably a list of source addresses, a list of ports, or the special string 'any' (or ['any'])
#
# If $arg is the empty list, it's possible that some selector of who should be allowed access
# has failed to yield a list of addresses, so we don't want to default to allow in that case
# (allow all would be the empty string). We return undef in this case, and templates using the
# return value of this function shouldn't output a rule unless it is a string.
function sunet::format_nft_set(String $prefix, Variant[String, Integer, Array] $arg) >> Variant[String, Undef] {
  if $arg =~ Array {
    $_arg = flatten($arg).unique
    $_arg ? {
      ['any'] => '',
      [] => undef,  # this is an error condition (see comment above)
      default => sprintf('%s { %s }', $prefix, $_arg.join(', '))
    }
  } else {
    $arg ? {
      'any' => '',
      default => sprintf('%s %s', $prefix, $arg)
    }
  }
}
