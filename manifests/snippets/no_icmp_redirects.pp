# No icmp redirects
define sunet::snippets::no_icmp_redirects($order=10) {
  $cfg = "/etc/sysctl.d/${order}_${title}.conf";
  file { $cfg:
    ensure  => file,
    content => "net.ipv4.conf.all.accept_redirects = 0\nnet.ipv6.conf.all.accept_redirects = 0\nnet.ipv4.conf.all.send_redirects = 0",
    notify  => Exec["refresh-sysctl-${title}"]
  }
  exec {"refresh-sysctl-${title}":
    command     => "sysctl -p ${cfg}",
    refreshonly => true
  }
}
