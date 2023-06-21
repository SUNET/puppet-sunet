class sunet::vc::standalone(
  String  $vc_version="latest",
  String  $mongodb_version="4.0.10",
  String  $mockca_sleep="20",
  String  $ca_token,
  String  $interface="ens3",
  Boolean $production=false,
  #hash with basic_auth key/value
) {

#  file { '/opt/vc':
#    ensure  => directory,
#    mode    =>  '0755',
#    owner   =>  'root',
#    group   =>  'root',
#  }

  file { '/opt/vc/config.yaml':
    ensure => file,
    mode   => '0400',
    owner  => '1000000000',
    group  => '1000000000',
    content => template("sunet/vc/standalone/config.yaml.erb")
   }

  file { '/opt/vc/haproxy.cfg':
    ensure  => file,
    mode    => '0644',
    owner   => 'root',
    group   => 'root',
    content =>  template("sunet/vc/standalone/haproxy.cfg.erb")
  }

  # Compose
  sunet::docker_compose { 'vc_standalone':
    content          => template('sunet/vc/standalone/docker-compose.yml.erb'),
    service_name     => 'vc',
    compose_dir      => '/opt',
    compose_filename => 'docker-compose.yml',
    description      => 'VC-standalone service',
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
