# Get eduroam
class sunet::geteduroam::radius(
  Array $resolvers = [],
  Boolean $ocsp = true,
  String $freeradius_tag = 'latest',
  String $ocsp_tag = 'latest',
  String $haproxy_tag = '3.0.2',
  Array $app_admins = [],
  Boolean $qa_federation = false,
  String $realm,
){

  class {'sunet::geteduroam::common': }
  sunet::nftables::allow { 'expose-allow-radius':
    from  => lookup('radius_servers', undef, undef,['192.36.171.226', '192.36.171.227', '2001:6b0:8:2::226', '2001:6b0:8:2::227'] ),
    port  => 1812,
    proto =>  'udp'
  }

  require sunet::certbot::sync::client::dirs
  file { '/opt/certbot-sync/renewal-hooks/deploy/geteduroam':
    ensure  => file,
    mode    => '0700',
    content => file('sunet/geteduroam/certbot-renewal-hook'),
  }

  $shared_secret = lookup('shared_secret', undef, undef, undef)
  file { '/opt/geteduroam/config/clients.conf':
    content => template('sunet/geteduroam/clients.conf.erb'),
    mode    => '0755',
  }

  if $ocsp {
      file { '/opt/geteduroam/config/eap.conf':
        content => template('sunet/geteduroam/eap.conf.erb'),
        mode    => '0755',
        }

  }

  sunet::docker_compose { 'geteduroam':
    content          => template('sunet/geteduroam/docker-compose-radius.yml.erb'),
    service_name     => 'geteduroam',
    compose_dir      => '/opt/',
    compose_filename => 'docker-compose.yml',
    description      => 'geteduroam',
  }

}
