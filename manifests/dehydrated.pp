class sunet::dehydrated($staging=false,
                         $domains=undef,
                         $httpd=false,
                         $apache=false,
                         $src_url='https://raw.githubusercontent.com/lukas2511/dehydrated/master/dehydrated') 
{
  $thedomains = $domains ? {
     undef   => hiera('letsencrypt_domains',hiera('dehydrated_domains',[{$::fqdn=>{'names'=>[$::fqdn]}}])),
     default => $domains
  }
  validate_array($thedomains)
  each($thedomains) |$domain_hash| {
     validate_hash($domain_hash)
  }
  $ca = $staging ? {
     false => 'https://acme-v01.api.letsencrypt.org/directory',
     true  => 'https://acme-staging.api.letsencrypt.org/directory'
  }
  ensure_resource('package','openssl',{ensure=>'latest'})
  sunet::remote_file { "/usr/sbin/dehydrated":
     remote_location => $src_url,
     mode            => '0755'
  }
  file { '/usr/sbin/letsencrypt.sh':
     ensure  => absent
  } ->
  file { '/usr/bin/le-ssl-compat.sh':
     ensure  => 'file',
     owner   => 'root',
     group   => 'root',
     mode    => '0755',
     content => template('sunet/dehydrated/le-ssl-compat.erb')
  } ->
  exec {'rename-etc-letsencrypt.sh':
     command => 'mv /etc/letsencrypt.sh /etc/dehydrated',
     onlyif  => 'test -d /etc/letsencrypt.sh'
  } ->
  file { '/etc/dehydrated':
     ensure  => 'directory',
     mode    => '0600'
  }
  file { '/etc/dehydrated/config':
     ensure  => 'file',
     content => template('sunet/dehydrated/config.erb')
  }
  exec { 'dehydrated-runonce':
     command     => '/usr/sbin/dehydrated -c && /usr/bin/le-ssl-compat.sh',
     refreshonly => true
  }
  file { '/etc/dehydrated/domains.txt':
     ensure  => 'file',
     content => template('sunet/dehydrated/domains.erb'),
     notify  => Exec['dehydrated-runonce']
  }
  cron {'dehydrated-cron':
     command => '/usr/sbin/dehydrated -c && /usr/bin/le-ssl-compat.sh',
     hour    => 2,
     minute  => 13
  }
  cron {'letsencrypt-cron': ensure => absent }
  if ($httpd) {
     package {'lighttpd':
        ensure  => latest
     } -> 
     service {'lighttpd':
        ensure  => running
     } ->
     ufw::allow { "allow-lighthttp":
        proto => 'tcp',
        port  => '80'
     }
     exec {'rename-var-www-letsencrypt':
        command => 'mv /var/www/letsencrypt /var/www/dehydrated',
        onlyif  => 'test -d /var/www/letsencrypt'
     } ->
     file { '/var/www/dehydrated':
        ensure  => 'directory',
        owner   => 'www-data',
        group   => 'www-data'
     } ->
     file { '/var/www/dehydrated/index.html':
        ensure  => file,
        owner   => 'www-data',
        group   => 'www-data',
        content => "<!DOCTYPE html><html><head><title>meep</title></head><body>meep<br/>meep</body></html>"
     }
     file {'/etc/lighttpd/conf-enabled/acme.conf':
        ensure  => 'file',
        content => template('sunet/dehydrated/lighttpd.conf'),
        notify  => Service['lighttpd']
     }
  }
  if ($apache) {
     ensure_resource('service','apache2',{})
     exec { 'enable-dehydrated-conf': 
        refreshonly  => true,
        command      => 'a2enconf dehydrated',
        notify       => Service['apache2']
     }
     file { '/var/www/dehydrated':
        ensure => directory,
        owner  => 'www-data',
        group  => 'www-data'
     } ->
     file { '/var/www/dehydrated/index.html':
        ensure  => file,
        owner   => 'www-data',
        group   => 'www-data',
        content => "<!DOCTYPE html><html><head><title>meep</title></head><body>meep<br/>meep</body></html>"
     } ->
     file { '/etc/apache2/conf-available/dehydrated.conf': 
        ensure  => 'file',
        content => template('sunet/dehydrated/apache.conf'),
        notify  => Exec['enable-dehydrated-conf'],
     }
  }
  each($thedomains) |$domain_hash| {
    each($domain_hash) |$domain,$info| {
      if (has_key($info,'ssh_key_type') and has_key($info,'ssh_key')) {
         sunet::rrsync { "/etc/dehydrated/certs/$domain":
            ssh_key_type => $info['ssh_key_type'],
            ssh_key      => $info['ssh_key']
         }
      }
    }
  }
}

class sunet::dehydrated::client($domain=undef, $server='acme-c.sunet.se', $user='root') {
  $home = $user ? {
    'root'  => '/root',
    default => "/home/${user}"
  }
  ensure_resource('file', "$home/.ssh", { ensure => 'directory' })
  ensure_resource('file', '/etc/dehydrated', { ensure => directory })
  ensure_resource('file', '/etc/dehydrated/certs', { ensure => directory })

  sunet::snippets::secret_file { "$home/.ssh/id_${domain}":
    hiera_key => "${domain}_ssh_key"
  } ->
  file { '/usr/bin/le-ssl-compat.sh':
     ensure  => 'file',
     owner   => 'root',
     group   => 'root',
     mode    => '0755',
     content => template('sunet/dehydrated/le-ssl-compat.erb')
  } ->
  sunet::ssh_keyscan::host { $server: }
  cron { "rsync_dehydrated_${domain}":
    command => "rsync -e \"ssh -i \$HOME/.ssh/id_${domain}\" -az root@${server}: /etc/dehydrated/certs/${domain} && /usr/bin/le-ssl-compat.sh",
    user    => $user,
    hour    => '*',
    minute  => '13'
  }
}
