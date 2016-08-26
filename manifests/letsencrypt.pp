class sunet::letsencrypt($domains={},
                         $staging=false,
                         $src_url='https://raw.githubusercontent.com/lukas2511/letsencrypt.sh/master/letsencrypt.sh') 
{
  validate_hash($domains)
  $ca = $staging ? {
     false => 'https://acme-v01.api.letsencrypt.org/directory',
     true  => 'https://acme-staging.api.letsencrypt.org/directory'
  }
  ensure_resource('package','openssl',{ensure=>'latest'})
  sunet::remote_file { "/usr/sbin/letsencrypt.sh":
     remote_location => $src_url,
     mode            => '0755'
  }
  file { '/etc/letsencrypt.sh':
     ensure  => 'directory',
     mode    => '0600'
  }
  file { '/etc/letsencrypt.sh/config':
     ensure  => 'file',
     content => template('sunet/letsencrypt/config.erb')
  }
  file { '/etc/letsencrypt.sh/domains.txt':
     ensure  => 'file',
     content => template('sunet/letsencrypt/domains.erb')
  }
  package {'lighttpd':
     ensure  => latest
  } -> 
  service {'lighttpd':
     ensure  => running
  } ->
  file { '/var/www/letsencrypt':
     ensure  => 'directory',
     owner   => 'www-data',
     group   => 'www-data'
  }
  file {'/etc/lighttpd/conf-enabled/acme.conf':
     ensure  => 'file',
     content => template('sunet/letsencrypt/lighttpd.conf'),
     notify  => Service['lighttpd']
  }
  core {'letsencrypt-cron':
     command => '/usr/sbin/letsencrypt.sh -c',
     hour    => 2,
     minute  => 13
  }
}
