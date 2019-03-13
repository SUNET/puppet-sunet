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
    notify  => Service['apache2'],
  }
}
