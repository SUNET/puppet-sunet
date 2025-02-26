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
  ensure_resource('file', "${home}/.ssh" {
      ensure    => directory,
      mode      => '0700',
      owner     => $user,
      group     => $user,
  });
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
    $key_path = "${home}/.ssh/id_${_ssh_id}"
    $safe_key = regsubst($_ssh_id, '[^0-9A-Za-z_]', '_', 'G')

    if lookup("${safe_key}_ssh_key", undef, undef, undef) { #Key is in secrets, write it to host
      ensure_resource('sunet::snippets::secret_file', $key_path, {
      hiera_key => "${safe_key}_ssh_key",
      })
    } else {
      if (!find_file($key_path)){
        sunet::snippets::ssh_keygen{$key_path:} #This will not overwrite an existing key
      }
    }
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
