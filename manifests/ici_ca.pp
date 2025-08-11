# set up ici ca
define sunet::ici_ca(
  $pkcs11_module = '/usr/lib/softhsm/libsofthsm.so',
  $pkcs11_pin = undef,
  $pkcs11_key_slot = '0',
  $pkcs11_key_id = 'abcd',
  $autosign_dir = undef,
  $autosign_type = 'peer',
  $public_repo_url = undef,
  $public_repo_dir = undef,
) {
  # Package is not built for anything newer than trusty
  if ($facts['os']['name'] == 'Ubuntu' and $facts['os']['release']['major'] == '22.04') {
    package { 'opensc': ensure => latest }
    package { 'libengine-pkcs11-openssl': ensure => latest }
    # Needed because: "/usr/lib/x86_64-linux-gnu/engines-3/pkcs11.so: undefined"
    # https://stackoverflow.com/questions/76758096/where-is-engine-pkcs11-so
    exec { '/usr/bin/mkdir -p /usr/lib/engines':
      unless  => '/usr/bin/test -d /usr/lib/engine'
    }
    file { '/usr/lib/engines/engine_pkcs11.so': ensure => link, target => '/usr/lib/x86_64-linux-gnu/engines-3/pkcs11.so' }

    apt::ppa { 'ppa:sunet/ppa': }
    package { 'ici': ensure => latest }
  } else {
    apt::ppa { 'ppa:leifj/ici': }
    package { 'ici': ensure => latest }
  }
  exec { "${name}_setup_ca":
    command => "/usr/bin/ici ${name} init",
    creates => "/var/lib/ici/${name}"
  }
  file { "${name}_ca_config":
    path    => "/var/lib/ici/${name}/ca.config",
    content => template('sunet/ici_ca/ca.config.erb')
  }
  if $public_repo_dir and $public_repo_url {
    cron { 'ici_publish':
      command => "test -f /var/lib/ici/${name}/ca.crt && /usr/bin/ici ${name} gencrl && /usr/bin/ici ${name} publish html ${public_repo_dir}",
      user    => 'root',
      minute  => '*/5'
    }
  }
}

# add cron job to auto-sign
define sunet::ici_ca::autosign(
  $ca = undef,
  $autosign_dir = undef,
  $autosign_type = 'client',
) {
  cron { "ici_autosign_${name}":
    command => "test -f /var/lib/ici/${ca}/ca.crt && /usr/bin/ici ${ca} issue -t ${autosign_type} -d 365 --copy-extensions ${autosign_dir}",
    user    => 'root',
    minute  => '*/5'
  }
}

# fetch certificate from ici-ca automatically and run a scriptherder job to see if it is valid
define sunet::ici_ca::rp(
  Boolean $monitor_infra_cert = true,
) {

  $host = $facts['networking']['fqdn']
  $ca = $name

  file { '/usr/bin/dl_ici_cert':
    content => template('sunet/ici_ca/dl_ici_cert.erb'),
    mode    => '0755'
  }
  exec { 'dl_infra_host_cert':
    command => "/usr/bin/dl_ici_cert ${ca} ${host}",
    onlyif  => "/usr/bin/test -f /etc/ssl/private/${host}_${ca}.key -a ! -f /etc/ssl/certs/${host}_${ca}.crt"
  }
  cron { 'refresh_infra_host_cert':
    command => "env RANDOM_SLEEP=30 /usr/bin/dl_ici_cert ${ca} ${host}",
    hour    => '1',
    minute  => '1'
  }
  file { '/usr/bin/check_infra_cert_expire':
    content => template('sunet/ici_ca/check_infra_cert_expire.erb'),
    mode    => '0755'
  }

  if ($monitor_infra_cert) {
    sunet::scriptherder::cronjob { 'check_infra_cert':
        cmd         => "/usr/bin/check_infra_cert_expire /etc/ssl/certs/${host}_infra.crt",
        minute      => '30',
        hour        => '8',
        ok_criteria => ['exit_status=0', 'max_age=25h'],
    }
  }
}
