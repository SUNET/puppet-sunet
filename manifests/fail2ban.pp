class sunet::fail2ban {

  package {'fail2ban':
      ensure => 'latest'
  } ->
  service {'fail2ban':
     ensure => 'running'
  }
}
