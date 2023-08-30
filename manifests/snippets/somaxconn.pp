# somaxconn
define sunet::snippets::somaxconn($maxconn=512) {
  $cfg = "/etc/sysctl.d/${title}_somaxconn.conf";
  file { $cfg:
    ensure  => file,
    content => "net.core.somaxconn=${maxconn}",
    notify  => Exec["refresh-sysctl-${title}"]
  }
  exec {"refresh-sysctl-${title}":
    command     => "sysctl -p ${cfg}",
    refreshonly => true
  }
}
