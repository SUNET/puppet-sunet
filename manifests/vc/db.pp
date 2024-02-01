class sunet::vc::db(
  String $interface               ="ens3",
  Boolean $production             =false,
  String $vc_version              = "latest",
  String $mongodb_version         = "4.0.10",
  String $mongo_user              = lookup('mongo_user'),
  String $mongo_pw                = lookup('mongo_pw'),
  String $redis_password          = lookup('redis_password')
) {

  sunet::ssh_keys { 'vcops':
    config => lookup('vcops_ssh_config', undef, undef, {}),
  }

 package { 'make': ensure => 'installed' }

  sunet::misc::system_user { 'sunet':
    username   => 'sunet',
    group      => 'sunet',
    shell      => '/bin/false',
    managehome => false
  }

  file { '/var/log/sunet':
    ensure => directory,
    mode    => '0770',
    group   => 'sunet',
    require =>  [ Group['sunet'] ],
  }

  file { '/opt/vc/Makefile':
    ensure => file,
    mode => '0744',
    owner => 'root',
    group => 'root',
    content => template("sunet/vc/ha/db/Makefile.erb")
  }

  file { '/opt/vc/certs':
    ensure  => directory,
    mode    => '0755',
    owner   => 'root',
    group   => 'root',
  }

  # Compose
  sunet::docker_compose { 'vc_db':
    content          => template('sunet/vc/ha/db/docker-compose.yml.erb'),
    service_name     => 'vc',
    compose_dir      => '/opt',
    compose_filename => 'docker-compose.yml',
    description      => 'VC-db service',
  }

  if $::facts['sunet_nftables_enabled'] == 'yes' {
    sunet::nftables::docker_expose { 'web_http_port' :
      iif           => $interface,
      allow_clients => 'any',
      port          => 80,
    }
    sunet::nftables::docker_expose { 'web_https_port' :
      iif           => $interface,
      allow_clients => 'any',
      port          => 443,
    }
    sunet::nftables::docker_expose { 'mongo_port' :
      iif           => $interface,
      allow_clients => 'any',
      port          => 27017,
    }
    sunet::nftables::docker_expose { 'redis_port':
      iif           => $interface,
      allow_clients => 'any',
      port          => 6379,
    }
  } else {
    sunet::misc::ufw_allow { 'web_mongo_redis_ports':
      from => 'any',
      port => ['80', '443', '27017', '6379']
    }
  }
}
