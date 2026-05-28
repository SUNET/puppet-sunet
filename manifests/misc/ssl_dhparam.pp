# Create a dhparams file
define sunet::misc::ssl_dhparam (
    $ssl_dhparam_file   = '/etc/ssl/dhparams.pem',
  ) {

  package {'openssl':
      ensure  => 'installed',
  }

  if $ssl_dhparam_file {
    exec {'nginx_generate_dh_group':
      command => "/usr/bin/openssl dhparam -out ${ssl_dhparam_file} 2048",
      unless  => "/usr/bin/test -s ${ssl_dhparam_file}",
      require => Package['openssl'],
    }
  }

}
