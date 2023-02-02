# Add a nft rule.
#
# Since rules are (per default) added to the same file, removing a rule statement from
# a manifest will also result in the rule being removed, since it is no longer written
# to this file.
#
# Usage example:
#
#  class nftables_nagiosnrpe {
#    nftables::rule { 'nagios_port_5666':
#          rule => 'add rule inet filter input ip saddr { 109.105.111.111/32 } tcp dport 5666 counter accept',
#      }
#  }
#
define sunet::nftables::rule(
    String $rule,
    Integer $order = 400,
    String $group = 'sunet_rules'
) {
  $rules_fn = "/etc/nftables/conf.d/${order}-${group}.nft"
  ensure_resource('concat', $rules_fn, {
    owner => 'root',
    group => 'root',
    mode  => '0400',
    notify  => Service['nftables'],
  })

  concat::fragment { $name:
    target  => $rules_fn,
    order   => '1000',
    content => sprintf("%s\n", $rule),
    require => Package['nftables'],
  }
}
