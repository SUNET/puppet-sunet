class sunet::vc::lab::datastore(
  String $vc_version              = "latest",
  String $mongodb_version         = "4.0.10",
  Boolean $production             = false,
  String $mongo_user              = lookup('mongo_user'),
  String $mongo_pw                = lookup('mongo_pw'),
  String $interface               = "ens3"
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

  file { '/opt/vc/config.yaml':
    ensure => file,
    mode   => '0600',
    owner  => 'root',
    group  => 'root',
    content => template("sunet/vc/lab/datastore/config.yaml.erb")
   }

  file { '/opt/vc/Makefile':
    ensure => file,
    mode => '0744',
    owner => 'root',
    group => 'root',
    content => template("sunet/vc/standalone/Makefile.erb")
  }

     # Compose
  sunet::docker_compose { 'vc_standalone':
    content          => template('sunet/vc/lab/datastore/docker-compose.yml.erb'),
    service_name     => 'vc',
    compose_dir      => '/opt',
    compose_filename => 'docker-compose.yml',
    description      => 'VC-lab-datastore service',
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
    sunet::nftables::docker_expose { 'jaeger_ui_port' :
      iif           => $interface,
      allow_clients => 'any',
      port          => 16686,
    }
  } else {
    sunet::misc::ufw_allow { 'web_ports':
      from => 'any',
      port => ['80', '443']
    }
  }
}
