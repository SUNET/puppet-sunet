class sunet::dehydrated(
  Boolean $staging = false,
  Boolean $httpd = false,
  Boolean $apache = false,
  Boolean $cron = true,
  Boolean $cleanup = false,
  String  $src_url = 'https://raw.githubusercontent.com/dehydrated-io/dehydrated/master/dehydrated',
  Array   $allow_clients = [],
  Integer $server_port = 80,
) {
  $conf = hiera_hash('dehydrated')
  if $conf !~ Hash {
    fail("Hiera key 'dehydrated' is not a hash")
  }
  if ! has_key($conf, 'domains') {
    fail("Hiera hash 'dehydrated' does not contain 'domains'")
    # Old default domains hash if none was set:
    # [{$::fqdn => {"names" => [$::fqdn]}}]
  }
  $thedomains = $conf['domains']
  if $thedomains !~ Array[Hash] {
    fail("Unknown format of 'domains' - bailing out (why it should be a list of hashes instead of just a hash I do not know)")
  }

  $ca = $staging ? {
     false => 'https://acme-v02.api.letsencrypt.org/directory',
     true  => 'https://acme-staging.api.letsencrypt.org/directory'
  }
  ensure_resource('package','openssl',{ensure=>'latest'})
  if $src_url =~ String[1] {
    sunet::remote_file { '/usr/sbin/dehydrated':
      remote_location => $src_url,
      mode            => '0755'
    }
  }

  exec {'rename-etc-letsencrypt.sh':
     command => 'mv /etc/letsencrypt.sh /etc/dehydrated',
     onlyif  => 'test -d /etc/letsencrypt.sh'
  }

  file {
    '/usr/sbin/letsencrypt.sh':
      ensure => absent
      ;
    '/usr/bin/le-ssl-compat.sh':
      ensure  => 'file',
      owner   => 'root',
      group   => 'root',
      mode    => '0755',
      content => template('sunet/dehydrated/le-ssl-compat.erb')
      ;
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
    # Run dehydrated once every time domains.txt changes; UPDATE 2018-02, since we're using the wrapper now Nagios stuff will break if we run the old command
    # command     => '/usr/local/bin/scriptherder --mode wrap --syslog --name dehydrated -- /usr/sbin/dehydrated -c && /usr/bin/le-ssl-compat.sh',
    command     => '/usr/local/bin/scriptherder --mode wrap --syslog --name dehydrated_per_domain -- /etc/dehydrated/dehydrated_wrapper.sh',
    refreshonly => true
  }

  if ($cron) {
    if ($cleanup) {
      $cmd = 'bash -c \'/usr/sbin/dehydrated --keep-going --no-lock -c && /usr/sbin/dehydrated --cleanup && /usr/bin/le-ssl-compat.sh\''
    } else {
      $cmd = 'bash -c \'/usr/sbin/dehydrated --keep-going --no-lock -c && /usr/bin/le-ssl-compat.sh\''
    }
    sunet::scriptherder::cronjob { 'dehydrated':
      cmd           => $cmd,
      special       => 'daily',
      ok_criteria   => ['exit_status=0','max_age=4d'],
      warn_criteria => ['exit_status=1','max_age=8d'],
    }
  }
  cron {'dehydrated-cron': ensure => absent }
  cron {'letsencrypt-cron': ensure => absent }

  if ($httpd) {
    sunet::dehydrated::lighttpd_server { 'dehydrated_lighttpd_server':
      allow_clients => $allow_clients,
      server_port   => $server_port,
    }
  }
  if ($apache) {
    sunet::dehydrated::apache_server { 'dehydrated_apache_server': }
  }
  if has_key($conf, 'clients') {
    $clients = $conf['clients']
  } else {
    $clients = false
  }

  # clients is supposed to be a hash
  # thedomains is supposed to be a list of hashes for some reason
  each($thedomains) |$domain_hash| {
    each($domain_hash) |$domain,$info| {
      # Example: $domain = 'foo.sunet.se',
      #          $info = {names => [foo.sunet.se],
      #                   clients => [frontend1.sunet.se, frontend2.sunet.se]
      #                  }
      if (has_key($info,'ssh_key_type') and has_key($info,'ssh_key')) {
         sunet::rrsync { "/etc/dehydrated/certs/${domain}":
           ssh_key_type       => $info['ssh_key_type'],
           ssh_key            => $info['ssh_key'],
           use_sunet_ssh_keys => true,
         }
      }
    }
  }

  if $clients =~ Hash[String, Hash] {
    each($clients) |$client,$client_info| {
      # Make a list of all the domains that list this client in their 'clients' list
      $domain_list1 = $thedomains.map |$domain_hash| {
        $domain_hash.map |$domain, $info| {
          if has_key($info, 'clients') {
            if ($client in $info['clients']) {
              $domain
            }
          }
        }
      }
      # Make a flat list without undef entrys
      $domain_list = flatten($domain_list1).filter |$this| { $this != undef }
      # Make a space separated string with all the domain names
      $dirs = join($domain_list, ' ')

      # anyone that ssh:s in with this ssh_key will get the certs authorized for this client packaged using tar
      sunet::snippets::ssh_command2 { "dehydrated_${client}" :
        command      => "/bin/tar cf - -C /etc/dehydrated/certs/ ${dirs}",
        ssh_key_type => $clients[$client]['ssh_key_type'],
        ssh_key      => $clients[$client]['ssh_key']
      }
    }
  } elsif $clients != undef {
    warning("Unknown format of 'clients' - ignoring")
  }
}

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

# If this class is used, only a single domain can be set up because puppet won't allow
# re-instantiating classes with different $domain
class sunet::dehydrated::client(
  String  $domain,
  String  $server='acme-c.sunet.se',
  String  $user='root',
  Boolean $ssl_links=false,
  Boolean $check_cert=true,
  String  $check_cert_port='443',
  Boolean $manage_ssh_key=true,
  Optional[String] $ssh_id=undef,
  Boolean $single_domain=true,
) {
  sunet::dehydrated::client_define { "domain_${domain}":
    domain          => $domain,
    server          => $server,
    user            => $user,
    ssl_links       => $ssl_links,
    check_cert      => $check_cert,
    check_cert_port => $check_cert_port,
    manage_ssh_key  => $manage_ssh_key,
    ssh_id          => $ssh_id,
    single_domain   => $single_domain,
  }
}

# Use this define directly if more than one domain is required
define sunet::dehydrated::client_define(
  String  $domain,
  String  $server='acme-c.sunet.se',
  String  $user='root',
  Boolean $ssl_links=false,
  Boolean $check_cert=true,
  String  $check_cert_port='443',
  Boolean $manage_ssh_key=true,
  Optional[String] $ssh_id=undef,  # Leave undef to use $domain, set to e.g. 'acme-c' to use the same SSH key for more than one cert
  Boolean $single_domain=true,
) {
  $home = $user ? {
    'root'  => '/root',
    default => "/home/${user}"
  }
  ensure_resource('file', "${home}/.ssh", { ensure => 'directory' })
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

  $_ssh_id = $ssh_id ? {
    undef   => $domain,
    default => $ssh_id,
  }
  if $manage_ssh_key {
    ensure_resource('sunet::snippets::secret_file', "${home}/.ssh/id_${_ssh_id}", {
      hiera_key => "${_ssh_id}_ssh_key",
      })
  }
  if $single_domain {
    cron { "rsync_dehydrated_${domain}":
      command => "rsync -e \"ssh -i \$HOME/.ssh/id_${_ssh_id}\" -az root@${server}: /etc/dehydrated/certs/${domain} && /usr/bin/le-ssl-compat.sh",
      user    => $user,
      hour    => '*',
      minute  => fqdn_rand(60),
    }
  } else {
    $minute_random = String(fqdn_rand(60))
    ensure_resource('sunet::scriptherder::cronjob',  "dehydrated_fetch_${server}", {
      cmd    => "sh -c 'ssh -Ti \$HOME/.ssh/id_${_ssh_id} root@${server} | /bin/tar xvf - -C /etc/dehydrated/certs && /usr/bin/le-ssl-compat.sh'",
      user   => $user,
      minute => $minute_random,
      ok_criteria   => ['exit_status=0', 'max_age=2h'],
      warn_criteria => ['exit_status=0', 'max_age=96h'],
    })
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
      cmd           => "/usr/bin/check_cert.sh ${domain} ${check_cert_port}",
      minute        => '18',
      hour          => '*',
      weekday       => '*',
      ok_criteria   => ['exit_status=0','max_age=2h'],
      warn_criteria => ['exit_status=1','max_age=1d'],
    }
  }
}
