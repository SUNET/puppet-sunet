class sunet::dehydrated(
  Boolean                 $staging=false,
  Optional[Array[String]] $domains=undef,
  Boolean                 $httpd=false,
  Boolean                 $apache=false,
  String                  $src_url = "https://raw.githubusercontent.com/lukas2511/dehydrated/master/dehydrated",
  Array                   $allow_clients = [],
) {
  $conf = hiera_hash('dehydrated')
  if ! is_hash($conf) {
    fail("Hiera key 'dehydrated' is not a hash")
  }
  if ! has_key($conf, 'domains') {
    fail("Hiera hash 'dehydrated' does not contain 'domains'")
    # Old default domains hash if none was set:
    # [{$::fqdn => {"names" => [$::fqdn]}}]
  }
  $thedomains = $conf['domains']

  #validate_array($thedomains)
  #each($thedomains) |$domain_hash| {
  #   validate_hash($domain_hash)
  #}
  $ca = $staging ? {
     false => 'https://acme-v01.api.letsencrypt.org/directory',
     true  => 'https://acme-staging.api.letsencrypt.org/directory'
  }
  ensure_resource('package','openssl',{ensure=>'latest'})
  if $src_url =~ String[1] {
    sunet::remote_file { '/usr/sbin/dehydrated':
      remote_location => $src_url,
      mode            => '0755'
    }
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
  file {
    '/etc/dehydrated':
      ensure  => 'directory',
      mode    => '0600',
      ;
    '/etc/dehydrated/config':
      ensure  => 'file',
      content => template('sunet/dehydrated/config.erb')
      ;
    '/etc/dehydrated/domains.txt':
      ensure  => 'file',
      content => template('sunet/dehydrated/domains.erb'),
      notify  => Exec['dehydrated-runonce']
      ;
  }
  exec { 'dehydrated-runonce':
    # Run dehydrated once every time domains.txt changes
    command     => '/usr/local/bin/scriptherder --mode wrap --syslog --name dehydrated -- /usr/sbin/dehydrated -c && /usr/bin/le-ssl-compat.sh',
    refreshonly => true
  }

  sunet::scriptherder::cronjob { 'dehydrated':
    cmd           => '/usr/sbin/dehydrated --keep-going --no-lock -c && /usr/bin/le-ssl-compat.sh',
    special       => 'daily',
    ok_criteria   => ['exit_status=0','max_age=4d'],
    warn_criteria => ['exit_status=1','max_age=8d'],
  }
  cron {'dehydrated-cron': ensure => absent }
  cron {'letsencrypt-cron': ensure => absent }

  if ($httpd) {
    sunet::dehydrated::lighttpd_server { 'dehydrated_lighttpd_server':
      allow_clients => $allow_clients,
    }
  }
  if ($apache) {
    sunet::dehydrated::apache_server { 'dehydrated_apache_server': }
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

# Run lighttpd on the acme-c host
define sunet::dehydrated::lighttpd_server(
  $allow_clients,
) {
  package {'lighttpd':
    ensure  => latest
  } ->
  service {'lighttpd':
    ensure  => running
  } ->
  sunet::misc::ufw_allow { 'allow-lighthttp':
    from => $allow_clients,
    port => '80'
  }
  exec {'rename-var-www-letsencrypt':
    command => 'mv /var/www/letsencrypt /var/www/dehydrated',
    onlyif  => 'test -d /var/www/letsencrypt'
  } ->
  file {
    '/var/www/dehydrated':
      ensure  => 'directory',
      owner   => 'www-data',
      group   => 'www-data'
      ;
    '/var/www/dehydrated/index.html':
      ensure  => file,
      owner   => 'www-data',
      group   => 'www-data',
      content => '<!DOCTYPE html><html><head><title>meep</title></head><body>meep<br/>meep</body></html>'
      ;
    '/etc/lighttpd/conf-enabled/acme.conf':
      ensure  => 'file',
      content => template('sunet/dehydrated/lighttpd.conf'),
      notify  => Service['lighttpd']
      ;
  }
}

# Run apache on the acme-c host
define sunet::dehydrated::apache_server(
) {
  ensure_resource('service','apache2',{})
  exec { 'enable-dehydrated-conf':
    refreshonly  => true,
    command      => 'a2enconf dehydrated',
    notify       => Service['apache2']
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

# If this class is used, only a single domain can be set up because puppet won't allow
# re-instantiating classes with different $domain
class sunet::dehydrated::client(
  String  $domain,
  String  $server='acme-c.sunet.se',
  String  $user='root',
  Boolean $ssl_links=false,
  Boolean $check_cert=false,
) {
  sunet::dehydrated::client_define { "domain_${domain}":
    domain     => $domain,
    server     => $server,
    user       => $user,
    ssl_links  => $ssl_links,
    check_cert => $check_cert,
  }
}

# Use this define directly if more than one domain is required
define sunet::dehydrated::client_define(
  String  $domain,
  String  $server='acme-c.sunet.se',
  String  $user='root',
  Boolean $ssl_links=false,
  Boolean $check_cert=false,
) {
  $home = $user ? {
    'root'  => '/root',
    default => "/home/${user}"
  }
  ensure_resource('file', "$home/.ssh", { ensure => 'directory' })
  ensure_resource('file', '/etc/dehydrated', { ensure => directory })
  ensure_resource('file', '/etc/dehydrated/certs', { ensure => directory })
  ensure_resource('file', '/usr/bin/le-ssl-compat.sh', {
    ensure  => 'file',
    owner   => 'root',
    group   => 'root',
    mode    => '0755',
    content => template('sunet/dehydrated/le-ssl-compat.erb'),
    })
  ensure_resource('sunet::ssh_keyscan::host', $server)

  sunet::snippets::secret_file { "$home/.ssh/id_${domain}":
    hiera_key => "${domain}_ssh_key"
  } ->
  cron { "rsync_dehydrated_${domain}":
    command => "rsync -e \"ssh -i \$HOME/.ssh/id_${domain}\" -az root@${server}: /etc/dehydrated/certs/${domain} && /usr/bin/le-ssl-compat.sh",
    user    => $user,
    hour    => '*',
    minute  => '13'
  }
  if ($ssl_links) {
     file { "/etc/ssl/private/${domain}.key": ensure => link, target => "/etc/dehydrated/certs/${domain}.key" }
     file { "/etc/ssl/certs/${domain}.crt": ensure => link, target => "/etc/dehydrated/certs/${domain}.crt" }
     file { "/etc/ssl/certs/${domain}-chain.crt": ensure => link, target => "/etc/dehydrated/certs/${domain}-chain.crt" }
  }
  # old name check_cert, should be removed on all systems by now
  #ensure_resource ('sunet::scriptherder::cronjob', 'check_cert', {ensure => 'absent', cmd => "/usr/bin/check_cert.sh ${domain}",
  #     minute        => '30',
  #     hour          => '9',
  #     weekday       => '1',
  #     ok_criteria   => ['exit_status=0'],
  #     warn_criteria => ['exit_status=1'],
  #   })
  if ($check_cert) {
     ensure_resource('file', '/usr/bin/check_cert.sh', {
       ensure  => 'file',
       owner   => 'root',
       group   => 'root',
       mode    => '0755',
       content => template('sunet/dehydrated/check_cert.erb'),
       })
     sunet::scriptherder::cronjob { "check_cert_${domain}":
       cmd           => "/usr/bin/check_cert.sh ${domain}",
       minute        => '30',
       hour          => '9',
       weekday       => '1',
       ok_criteria   => ['exit_status=0','max_age=8d'],
       warn_criteria => ['exit_status=1','max_age=15d'],
     }
  }
}
