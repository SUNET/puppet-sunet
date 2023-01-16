# Shim layer between old sunet::misc::ufw_allow and sunet::nftables.
# Typing of the arguments is so weak because we allow strings, arrays of strings, unflattened arrays etc.
define sunet::nftables::ufw_allow_compat(
  $from,           # Allow traffic 'from' this IP (or list of IP:s).
  $port,           # Allow traffic to this port (or list of ports).
  $to     = 'any',  # Allow traffic to this IP (or list of IP:s). 'any' means both IPv4 and IPv6.
  $proto  = 'tcp',  # Allow traffic using this protocol (or list of protocols).
  String $ruleset = '500-sunet_ufw_allow',
) {
    # $safe_name = regsubst($title, '[^0-9A-Za-z_]', '_', 'G')

    $rules_fn = "/etc/nftables/conf.d/${ruleset}.nft"
    ensure_resource('concat', $rules_fn, {
      owner  => 'root',
      group  => 'root',
      mode   => '0400',
      notify => Service['nftables'],
    })

    $src_v4 = filter(flatten([$from])) | $this | { is_ipaddr($this, 4) }
    $src_v6 = filter(flatten([$from])) | $this | { is_ipaddr($this, 6) }

    $dst_v4 = filter(flatten([$to])) | $this | { is_ipaddr($this, 4) }
    $dst_v6 = filter(flatten([$to])) | $this | { is_ipaddr($this, 6) }

    $port_set = sunet::format_nft_set('dport', $port)

    each(flatten([$proto])) |$_proto| {
      if ($src_v4 and $src_v4 != []) or flatten([$from]) == ['any'] {
        $src_set_v4 = flatten([$from]) == ['any'] ? {
          true    => '',
          default => sunet::format_nft_set('ip saddr', $src_v4)
        }
        $dst_set_v4 = sunet::format_nft_set('ip daddr', $dst_v4)
        $rule_v4 = "add rule inet filter input ${src_set_v4} ${dst_set_v4} ${_proto} ${port_set} counter accept comment \"${name}\"\n"
        concat::fragment { "${name}_${_proto}_rule_v4":
          target  => $rules_fn,
          order   => '2000',
          content => $rule_v4,
        }
      }

      if ($src_v6 and $src_v6 != []) or flatten([$from]) == ['any'] {
        $src_set_v6 = flatten([$from]) == ['any'] ? {
          true    => '',
          default => sunet::format_nft_set('ip6 saddr', $src_v6)
        }
        $dst_set_v6 = sunet::format_nft_set('ip6 daddr', $dst_v6)
        $rule_v6 = "add rule inet filter input ${src_set_v6} ${dst_set_v6} ${_proto} ${port_set} counter accept comment \"${name}\"\n"
        concat::fragment { "${name}_${_proto}_rule_v6":
          target  => $rules_fn,
          order   => '3000',
          content => $rule_v6,
        }
      }
    }
}
