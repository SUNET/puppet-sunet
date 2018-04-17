class sunet::ipam::web_config {

  require sunet::ipam::main

  # The array of IP addresses that are allowed to communicate over https.
  $https_allow_servers = hiera_array('https_allow_servers',[])

  ufw::allow {'allow_http': ip => 'any', port => '80'}
  sunet::misc::ufw_allow { 'allow_https':
    from => $https_allow_servers,
    port => '443',
  }
  package { 'apache2':
  	ensure => installed,
  }
  -> service { 'apache2':
      ensure => running,
      enable => true,
      }

  # Domain name of the host which uses this manifest. The variable is used in nipap-default.conf.erb
  # and nipap-www.ini.erb template.
  $domain = $::domain

  # Configuration of the web service follows.
  file { '/etc/apache2/sites-available/nipap-default.conf':
    ensure  => file,
    mode    => '0644',
    content => template('sunet/ipam/nipap-default.conf.erb'),
    notify  => Service['apache2'],
  }
  -> file { '/etc/apache2/sites-available/nipap-ssl.conf':
      ensure  => file,
      mode    => '0644',
      content => template('sunet/ipam/nipap-ssl.conf.erb'),
      }
  -> file { '/etc/apache2/sites-enabled/nipap-ssl.conf':
      ensure => link,
      target => '/etc/apache2/sites-available/nipap-ssl.conf',
      }
  -> file { '/etc/apache2/sites-enabled/nipap-default.conf':
      ensure => link,
      target => '/etc/apache2/sites-available/nipap-default.conf',
      }
  -> file { '/etc/nipap/nipap-www.ini':
      ensure  => file,
      mode    => '0644',
      content => template('sunet/ipam/nipap-www.ini.erb'),
      }
  -> file { '/var/cache/nipap-www':
      ensure  => directory,
      owner   => 'www-data',
      group   => 'www-data',
      mode    => '0755',
      recurse => true,
      }
}

