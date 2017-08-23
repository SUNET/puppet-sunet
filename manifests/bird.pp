class sunet::bird(
  String $bird      = 'bird',
  String $bird6     = 'bird6',
  String $package   = 'bird-bgp',
  String $username  = 'bird',
  Integer $uid      = 501,
  Integer $gid      = 501,
  String $router_id = $::ipaddress_default,
) {
  $my_router_id = $router_id ? {
     undef   => "${::ipaddress_eth0}",
     default => $router_id
  }
  group {$username:
    ensure   => present,
    gid      => $gid,
  } ->
  user  {$username:
    ensure   => present,
    password => '!!',
    uid      => $uid,
    gid      => $gid
  } ->
  package {$package: ensure => latest } ->
  file { "/etc/bird":
    ensure   => directory,
    owner    => $username,
    group    => $username
  } ->
  file { "/etc/bird/conf.d": ensure => directory } ->
  file { "/etc/bird/conf6.d": ensure => directory } ->
  concat { "/etc/bird/bird.conf":
    owner    => $username,
    group    => $username,
    mode     => '0644',
    notify   => Service[$bird]
  }
  concat { "/etc/bird/bird6.conf":
    owner    => $username,
    group    => $username,
    mode     => '0644',
    notify   => Service[$bird6]
  }
  concat::fragment {'bird_header':
    target   => "/etc/bird/bird.conf",
    order    => '10',
    content  => template("sunet/bird/bird.conf.erb"),
    notify   => Service[$bird]
  }
  concat::fragment {'bird6_header':
    target   => "/etc/bird/bird6.conf",
    order    => '10',
    content  => template("sunet/bird/bird6.conf.erb"),
    notify   => Service[$bird6]
  }
  service {$bird: ensure => running }
  service {$bird6: ensure => running }
  ufw::allow {"allow-bird-bgp-tcp": ip => "any", port => "179", proto => "tcp" }

  file { "/usr/lib/nagios/plugins/check_bird_peers" :
    ensure  => 'file',
    mode    => '0751',
    group   => 'nagios',
    require => Package['nagios-nrpe-server'],
    content => template('sunet/bird/check_bird_peers.erb'),
  }

  sunet::nagios::nrpe_command {'check_bird_peers':
    command_line => '/usr/lib/nagios/plugins/check_bird_peers',
  }

  sunet::nagios::nrpe_command {'check_bird_peers6':
    command_line => '/usr/lib/nagios/plugins/check_bird_peers -s /var/run/bird/bird6.ctl',
  }
}
