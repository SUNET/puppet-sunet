# Wrapper to setup a OpenIDFed TA host
class sunet::oidf::ta(
  String $hostname              = undef,
  String $inmor_version         = undef,
  Optional[Boolean] $acmed      = true
){
  $secret_key = lookup('inmor_secret_key', undef, undef, 'your-production-secret-key')
  $mfa_key = lookup('inmor_mfa_key', undef, undef, 'your-production-MFA-key')

  sunet::docker_compose { 'oidf-ta':
    content          => template('sunet/oidf/docker-compose-ta.yml.erb'),
    service_name     => 'oidf-ta',
    compose_dir      => '/opt/',
    compose_filename => 'docker-compose.yml',
    description      => 'OpenIDFed TA',
  } ->  file { '/opt/oidf-ta/taconfig.toml':
    content => template('sunet/oidf/taconfig.toml.erb'),
    mode    => '0755',
  } -> file { '/opt/oidf-ta/localsettings.py':
    content => template('sunet/oidf/localsettings.py.erb'),
    mode    => '0755',
    replace => false,
  } -> file {'/opt/oidf-ta/keys/':
    ensure => 'directory',
    mode   => '0700',
    owner  => '999'
  } -> if lookup('inmor_key', undef, undef, undef) != undef {
    sunet::snippets::secret_file { '/opt/oidf-ta/keys/private.json':
      hiera_key => 'inmor_key',
      mode      => '0644',
    }
    # assume cert is in cosmos repo
  } else {
    exec { 'generate_privat_public_keys':
      command => "docker run --rm -v /opt/oidf-ta/keys:/app/keys docker.sunet.se/inmor:${inmor_version} /app/inmor-keygeneration --type RS256 --output /app/keys --force"
    }
  }

  file { '/opt/oidf-ta/updateKeys.bash':
    ensure  => 'file',
    mode    => '0700',
    content => file('sunet/oidf/updateKeys.bash')
  } -> sunet::scriptherder::cronjob { 'updateKeys':
    cmd           => '/opt/oidf-ta/updateKeys.bash',
    minute        => '*/5',
    ok_criteria   => ['exit_status=0', 'max_age=1h'],
    warn_criteria => ['exit_status=1', 'max_age=2h'],
  } -> sunet::scriptherder::cronjob { 'updateCollection':
    cmd           => "docker exec oidf-ta-ta-1 /app/inmor-collection --config /app/taconfig.toml https://${hostname}",
    minute        => '*/30',
    ok_criteria   => ['exit_status=0', 'max_age=1h'],
    warn_criteria => ['exit_status=1', 'max_age=2h'],
  }

  #NGINX Conf
  file { '/opt/nginx_conf':
    ensure => directory,
    mode   => '0755',
    owner  => 'root',
    group  => 'root'
  } -> file { '/opt/nginx_conf/default.conf':
    ensure  => 'file',
    mode    => '0755',
    owner   => 'root',
    group   => 'root',
    content => file('sunet/oidf/ta-nginx_default.conf')
  }
  sunet::nftables::allow { 'expose-TA-ssl':
    from => 'any',
    port => 443,
  }

  if ($acmed) {
    file { '/etc/letsencrypt/renewal-hooks/deploy/ta-renewal-hook':
      ensure  => 'file',
      mode    => '0755',
      owner   => 'root',
      group   => 'root',
      content => file('sunet/oidf/ta-renewal-hook')
    }
  } else {
    sunet::nftables::allow { 'expose-always-https':
      from => 'any',
      port => 80,
    }
  }
}