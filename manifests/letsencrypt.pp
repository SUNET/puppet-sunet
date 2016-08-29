class sunet::letsencrypt($staging=false,
                         $src_url='https://raw.githubusercontent.com/lukas2511/letsencrypt.sh/master/letsencrypt.sh') 
{
  $domains = hiera('letsencrypt_domains')
  validate_array($domains)
  each($domains) |$domain_hash| {
     validate_hash($domain_hash)
  }
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
  exec { 'letsencrypt-runonce':
     command     => '/usr/sbin/letsencrypt.sh -c',
     refreshonly => true
  }
  file { '/etc/letsencrypt.sh/domains.txt':
     ensure  => 'file',
     content => template('sunet/letsencrypt/domains.erb'),
     notify  => Exec['letsencrypt-runonce']
  }
  package {'lighttpd':
     ensure  => latest
  } -> 
  service {'lighttpd':
     ensure  => running
  } ->
  ufw::allow { "allow-lighthttp":
     proto => 'tcp',
     port  => '80'
  } ->
  file { '/var/www/letsencrypt':
     ensure  => 'directory',
     owner   => 'www-data',
     group   => 'www-data'
  } ->
  file { '/var/www/letsencrypt/index.html':
     ensure  => file,
     owner   => 'www-data',
     group   => 'www-data',
     content => "<!DOCTYPE html><html><head><title>meep</title></head><body>meep<br/>meep</body></html>"
  }
  file {'/etc/lighttpd/conf-enabled/acme.conf':
     ensure  => 'file',
     content => template('sunet/letsencrypt/lighttpd.conf'),
     notify  => Service['lighttpd']
  }
  cron {'letsencrypt-cron':
     command => '/usr/sbin/letsencrypt.sh -c',
     hour    => 2,
     minute  => 13
  }
  each($domains) |$domain_hash| {
    each($domain_hash) |$domain,$info| {
      if ($info['ssh_key_type'] and $info['ssh_key']) {
         sunet::rrsync { "/etc/letsencrypt/certs/$domain":
            ssh_key_type => $info['ssh_key_type'],
            ssh_key      => $info['ssh_key']
         }
      }
    }
  }
}

class sunet::letsencrypt::client($domain=undef, $server='acme-c.sunet.se', $user='root') {
  $home = $user ? {
    'root'  => '/root',
    default => "/home/${user}"
  }
  ensure_resource('file', "$home/.ssh", { ensure => 'directory' })
  ensure_resource('file', '/etc/letsencrypt', { ensure => directory })
  ensure_resource('file', '/etc/letsencrypt/certs', { ensure => directory })

  sunet::snippets::secret_file { "$home/.ssh/id_${domain}":
    hiera_key => "${domain}_ssh_key"
  } ->
  cron { "rsync_letsencrypt_${domain}":
    command => "rsync -e \"ssh -i \$HOME/.ssh/id_${domain}\" -az root@${server}: /etc/letsencrypt/certs/${domain}",
    user    => $user,
    hour    => '*',
    minute  => '13'
  }
}
