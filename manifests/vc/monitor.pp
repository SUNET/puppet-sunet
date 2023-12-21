class sunet::vc::monitor(
  String $interface               ="ens3",
  Boolean $production             =false,
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
    content => template("sunet/vc/monitor/config.yaml.erb")
   }

  file { '/opt/vc/haproxy.cfg':
    ensure  => file,
    mode    => '0644',
    owner   => 'root',
    group   => 'root',
    content =>  template("sunet/vc/monitor/haproxy.cfg.erb")
  }

  file { '/opt/vc/Makefile':
    ensure => file,
    mode => '0744',
    owner => 'root',
    group => 'root',
    content => template("sunet/vc/monitor/Makefile.erb")
  }

  file { '/opt/vc/certs':
    ensure  => directory,
    mode    => '0755',
    owner   => 'root',
    group   => 'root',
  }

  # Compose
  sunet::docker_compose { 'vc_monitor':
    content          => template('sunet/vc/monitor/docker-compose.yml.erb'),
    service_name     => 'vc',
    compose_dir      => '/opt',
    compose_filename => 'docker-compose.yml',
    description      => 'VC-monitor service',
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
  } else {
    sunet::misc::ufw_allow { 'web_ports':
      from => 'any',
      port => ['80', '443']
    }
  }
}