# exabgp.conf
define sunet::lb::exabgp::config(
  String               $monitor = '/etc/bgp/monitor',
  Enum['text', 'json'] $encoder = 'text',
  String               $config  = '/etc/bgp/exabgp.conf',
  Enum['3', '4']       $exabgp_version = '3',  # slighly different config in 3 and 4
  $notify = undef,
) {
  concat { $config:
    owner  => 'root',
    group  => 'root',
    mode   => '0644',
    notify => $notify,
  }

  concat::fragment { 'exabgp_header':
    target  => $config,
    order   => '10000',
    content => template('sunet/lb/exabgp/exabgp.conf_header.erb'),
    notify  => $notify,
  }

  concat::fragment { 'exabgp_footer':
    target  => $config,
    order   => '10',
    content => template('sunet/lb/exabgp/exabgp.conf_footer.erb'),
    notify  => $notify,
  }
}
