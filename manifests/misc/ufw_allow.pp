# Open host firewall to allow clients to access a service.
define sunet::misc::ufw_allow(
  $from,           # Allow traffic 'from' this IP (or list of IP:s).
  $port,           # Allow traffic to this port (or list of ports).
  $to     = 'any',  # Allow traffic to this IP (or list of IP:s). 'any' means both IPv4 and IPv6.
  $proto  = 'tcp',  # Allow traffic using this protocol (or list of protocols).
  $ensure = 'present',
  String $ruleset = '500-sunet_ufw_allow',
  ) {
  if $::sunet_nftables_opt_in == 'yes' or ( $::operatingsystem == 'Ubuntu' and versioncmp($::operatingsystemrelease, '22.04') >= 0 ) {
    if $ensure == 'present' {
      # $safe_name = regsubst($title, '[^0-9A-Za-z_]', '_', 'G')

      $rules_fn = "/etc/nftables/conf.d/${ruleset}.nft"
      ensure_resource('concat', $rules_fn, {
        owner => 'root',
        group => 'root',
        mode  => '0400',
      })


      # concat::fragment { "${name}_rules_header":
      #   target  => $rules_fn,
      #   order   => '10000',
      #   content => "# This file is (re-)created by Puppet. DO NOT EDIT!\n",
      # }

      $src_v4 = filter(flatten([$from])) | $this | { is_ipaddr($this, 4) }
      $src_v6 = filter(flatten([$from])) | $this | { is_ipaddr($this, 6) }

      $dst_v4 = filter(flatten([$to])) | $this | { is_ipaddr($this, 4) }
      $dst_v6 = filter(flatten([$to])) | $this | { is_ipaddr($this, 6) }

      # warning("SRC v4 ${src_v4}")
      # warning("SRC v6 ${src_v6}")

      $port_set = sunet::misc::format_nft_set('dport', $port)

      each(flatten([$proto])) |$_proto| {
        if $src_v4 and $src_v4 != [] {
          $src_set_v4 = sunet::misc::format_nft_set('ip saddr', $src_v4)
          $dst_set_v4 = sunet::misc::format_nft_set('ip daddr', $dst_v4)
          $rule_v4 = "add rule inet filter input ${src_set_v4} ${dst_set_v4} ${_proto} ${port_set} counter accept comment \"${name}\"\n"
          concat::fragment { "${name}_${_proto}_rule_v4":
            target  => $rules_fn,
            order   => '2000',
            content => $rule_v4,
            notify  => Service['nftables'],
          }
        }

        if $src_v6 and $src_v6 != [] {
          $src_set_v6 = sunet::misc::format_nft_set('ip6 saddr', $src_v6)
          $dst_set_v6 = sunet::misc::format_nft_set('ip6 daddr', $dst_v6)
          $rule_v6 = "add rule inet filter input ${src_set_v6} ${dst_set_v6} ${_proto} ${port_set} counter accept comment \"${name}\"\n"
          concat::fragment { "${name}_${_proto}_rule_v6":
            target  => $rules_fn,
            order   => '3000',
            content => $rule_v6,
            notify  => Service['nftables'],
          }
        }
      }

      # Make output more readable by inserting separators between blocks
      # each(['1999', '2999', '3999']) | $num | {
      #   ensure_resource('concat::fragment', "${safe_name}_separator_${num}", {
      #     target  => $rules_fn,
      #     order   => $num,
      #     content => "\n\n"
      #   })
      # }
    }
  } else {
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

function sunet::misc::format_nft_set(String $prefix, Variant[String, Integer, Array, Undef] $arg) >> Variant[String, Undef] {
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
