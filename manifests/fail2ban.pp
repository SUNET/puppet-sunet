class sunet::fail2ban {

  package {'fail2ban':
      ensure => 'latest'
  } ->
  service {'fail2ban':
     ensure => 'running'
  }
  exec {"fail2ban_defaults": 
     refreshonly => true,
     subscribe   => Service['fail2ban'],
     command     => "sleep 5; /usr/bin/fail2ban-client set ssh bantime 600800"
  }
}
