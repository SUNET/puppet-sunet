# Run apache on the acme-c host
define sunet::dehydrated::apache_server(
) {
  ensure_resource('service','apache2',{})
  exec { 'enable-dehydrated-conf':
    refreshonly => true,
    command     => 'a2enconf dehydrated',
    notify      => Service['apache2']
  }
  file {
    '/var/www/dehydrated':
      ensure => directory,
      owner  => 'www-data',
      group  => 'www-data'
      ;
    '/var/www/dehydrated/index.html':
      ensure  => file,
      owner   => 'www-data',
      group   => 'www-data',
      content => '<!DOCTYPE html><html><head><title>meep</title></head><body>meep<br/>meep</body></html>'
      ;
    '/etc/apache2/conf-available/dehydrated.conf':
      ensure  => 'file',
      content => template('sunet/dehydrated/apache.conf'),
      notify  => Exec['enable-dehydrated-conf'],
      ;
  }
}
