# Wrapper to setup a OpenIDFed TA host
class sunet::oidf::ta(
  String $hostname              = undef,
  String $inmor_version         = undef
){
  sunet::docker_compose { 'oidf-ta':
    content          => template('sunet/oidf/docker-compose-ta.yml.erb'),
    service_name     => 'oidf-ta',
    compose_dir      => '/opt/',
    compose_filename => 'docker-compose.yml',
    description      => 'OpenIDFed TA',
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
  sunet::nftables::allow { 'expose-admin':
    from => 'any',
    port => 8000,
  }
  sunet::nftables::allow { 'expose-always-https':
    from => 'any',
    port => 80,
  }
  sunet::nftables::allow { 'expose-TA-ssl':
    from => 'any',
    port => 443,
  }
  sunet::nftables::allow { 'expose-admin-ssl':
    from => 'any',
    port => 8443,
  }

  sunet::snippets::secret_file { '/opt/oidf-ta/private.json':
    hiera_key => 'inmor_key',
    mode      => '0644',
  }
}