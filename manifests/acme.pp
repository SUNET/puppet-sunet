# acme
class sunet::acme(
  String  $server = 'acme-c.sunet.se',
  Boolean $ufw_80 = false,
) {
  file { '/etc/apache2/conf-available/acme.conf':
    content => template('sunet/acme/apache-conf.erb'),
    notify  => Service['apache2'],
  }

  exec { 'acme: enable proxy modules':
    command => 'a2enmod proxy proxy_http',
    creates => ['/etc/apache2/mods-enabled/proxy.load',
                '/etc/apache2/mods-enabled/proxy_http.load'],
    notify  => Service['apache2'],
  }

  exec { 'acme: enable acme conf':
    command => 'a2enconf acme',
    creates => '/etc/apache2/conf-enabled/acme.conf',
    notify  => Service['apache2'],
  }

  if $ufw_80 {
    sunet::misc::ufw_allow { 'acme: ':
      from => 'any',
      port => 80,
    }
  }
}
