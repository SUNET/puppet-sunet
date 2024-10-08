define sunet::exabgp::config(
  String               $monitor = '/etc/bgp/monitor',
  Enum['text', 'json'] $encoder = 'text',
  String               $config  = '/etc/bgp/exabgp.conf',
) {
  concat { $config:
    owner => 'root',
    group => 'root',
    mode  => '0644',
    #notify   => Service['exabgp'],
  }

  concat::fragment { 'exabgp_header':
    target  => $config,
    order   => '10000',
    content => template('sunet/exabgp/exabgp.conf_header.erb'),
    #notify  => Service['exabgp'],
  }

  concat::fragment { 'exabgp_footer':
    target  => $config,
    order   => '10',
    content => template('sunet/exabgp/exabgp.conf_footer.erb'),
    #notify  => Service['exabgp'],
  }
}
