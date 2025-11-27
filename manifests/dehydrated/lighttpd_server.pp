# Run lighttpd on the acme-c host
define sunet::dehydrated::lighttpd_server(
  Array   $allow_clients,
  Integer $server_port = 80,
) {
  package {'lighttpd':
    ensure => latest
  }
  service {'lighttpd':
    ensure => running
  }
  sunet::misc::ufw_allow { 'allow-lighthttp':
    from => $allow_clients,
    port => $server_port,
  }
  exec { 'lighttpd_server_port':
    command => "/bin/sed -r -i -e 's/^(server.port\s*= ).*/\\1${server_port}/' /etc/lighttpd/lighttpd.conf",
    unless  => "/bin/grep -qx 'server.port\s*=\s*${server_port}'",
    notify  => Service['lighttpd'],
    require => Package['lighttpd'],
  }
  exec {'rename-var-www-letsencrypt':
    command => 'mv /var/www/letsencrypt /var/www/dehydrated',
    onlyif  => 'test -d /var/www/letsencrypt'
  }
  file {
    '/var/www/dehydrated':
      ensure => 'directory',
      owner  => 'www-data',
      group  => 'www-data',
      mode   => '0750',
      ;
    '/var/www/dehydrated/index.html':
      ensure  => file,
      owner   => 'www-data',
      group   => 'www-data',
      content => "<!DOCTYPE html><html><head><title>meep</title></head>\n<body>\n  meep<br/>\n  meep\n</body></html>\n"
      ;
    '/etc/lighttpd/conf-enabled/acme.conf':
      ensure  => 'file',
      content => template('sunet/dehydrated/lighttpd.conf'),
      notify  => Service['lighttpd']
      ;
  }
}
