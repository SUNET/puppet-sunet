# Make a nftables { set }
function sunet::nftables::misc::format_nft_set(String $prefix, Variant[String, Integer, Array, Undef] $arg) >> Variant[String, Undef] {
  if $arg =~ Array {
    $arg ? {
      [] => undef,
      default => sprintf('%s { %s }', $prefix, $arg.join(', '))
    }
  } elsif $arg =~ String {
    $arg ? {
      'any' => undef,
      default => [$prefix, $arg].join(' ')
    }
  } elsif $arg =~ Integer {
    [$prefix, $arg].join(' ')
  }
}
