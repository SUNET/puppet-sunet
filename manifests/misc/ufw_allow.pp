# Open host firewall to allow clients to access a service.
define sunet::misc::ufw_allow(
  $from,           # Allow traffic 'from' this IP (or list of IP:s).
  $port,           # Allow traffic to this port (or list of ports).
  $to     = 'any',  # Allow traffic to this IP (or list of IP:s). 'any' means both IPv4 and IPv6.
  $proto  = 'tcp',  # Allow traffic using this protocol (or list of protocols).
  $ensure = 'present',
  ) {

  # if $to is '', turn it into 'any'.
  # ufw module behaviour of changing '' to $ipaddress_eth0 or $ipaddress does not make much sense.
  $to1 = $to ? {
    ''      => 'any',
    default => $to,
  }

  each(flatten([$from])) |$_from| {
    if $_from != 'any' and ! is_ipaddr($_from) {
      fail("'from' is not an IP address: ${_from}")
    }
    each(flatten([$to1])) |$_to| {
      if $_to != 'any' and ! is_ipaddr($_to) {
        fail("'to' is not an IP address: ${_to}")
      }
      each(flatten([$port])) |$_port| {
        each(flatten([$proto])) |$_proto| {
          $unique_name = "_ufw_allow__from_${_from}__to_${_to}__${_port}/${_proto}"

          if $::sunet_nftables_opt_in == 'yes' {
            if $ensure == 'present' {
              $_family = 'ip'
              if is_ipaddr($_from, 6) || is_ipaddr($_to, 6) {
                $_family = 'ip6'
              }
              $src = $_from ? {
                'any'   => '',
                default => "${_family} saddr { ${_from} }"
              }
              $dst = $_to ? {
                'any'   => '',
                default => "${_family} daddr { ${_to} }"
              }
              $rule = "add rule inet filter input ${src} ${dst} ${_proto} dport ${_port} counter accept"
              sunet::snippets::file_line {
                $unique_name:
                  filename => '/etc/nftables/conf.d/sunet_ufw_allow.nft',
                  line     => $rule,
                  notify   => Service['nftables'],
                  require  => Package['nftables'],
                  ;
              }
            }
          } else {
            ensure_resource('ufw::allow', $unique_name, {
              ensure => $ensure,
              from   => $_from,
              ip     => $_to,
              proto  => $_proto,
              port   => sprintf('%s', $_port),
            })
          }
        }
      }
    }
  }
}
