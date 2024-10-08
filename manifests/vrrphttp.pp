class sunet::vrrphttp() {
  package { ['ipvsadm','keepalived']: ensure => latest }
  -> file { '/usr/local/bin': ensure => directory }
  -> file { '/usr/local/bin/update-keepalived-conf':
      path    => '/usr/local/bin/update-keepalived-conf',
      content => template('sunet/vrrphttp/update-keepalived-conf.erb'),
      mode    => '0755'
  }
  -> file { '/etc/keepalived/bypass_ipvs.sh':
      path    => '/etc/keepalived/bypass_ipvs.sh',
      content => template('sunet/vrrphttp/bypass_ipvs.sh.erb'),
      mode    => '0755'
  }
}
