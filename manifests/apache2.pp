# apache2
class sunet::apache2(
) {
  ensure_packages(['apache2'])

  service { 'apache2':
    ensure  => 'running',
    enable  => true,
    require => Package['apache2'],
  }

  exec { 'enable TLS':
    command => 'a2enmod ssl',
    creates => '/etc/apache2/mods-enabled/ssl.load',
    notify  => Service['apache2'],
  }
}
