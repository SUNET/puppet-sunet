# Run bankid-idp with compose
class sunet::bankidp(
  String $instance,
  Array $environments_extras = [],
  Array $resolvers = [],
  Array $volumes_extras = [],
  Array $ports_extras = [],
  String $imagetag='latest',
  String $tz = 'Europe/Stockholm',
  String $bankid_home = '/opt/bankidp',
  String $spring_config_import = '/config/service.yml',
  String $service_name = 'bankidp.qa.swamid.se',
  Boolean $prod = true,
  Boolean $app_node = false,
  Boolean $redis_node = false,
) {

  $apps = $facts['bankid_cluster_info']['apps']
  $redises = $facts['bankid_cluster_info']['redises']

  if $app_node {
    class { 'sunet::frontend::register_sites':
      sites => {
        $service_name => {
          frontends => ['se-fre-lb-1.sunet.se', 'se-tug-lb-1.sunet.se'],
          port      => '443',
        }
      }
    }
    ensure_resource('sunet::misc::create_dir', '/opt/bankidp/config/', { owner => 'root', group => 'root', mode => '0750'})
    file { '/opt/bankidp/config/service.yml':
      content => template('sunet/bankidp/service.yml.erb'),
      mode    => '0755',
    }

    $signing_cert = $prod ? {
      true => 'md-signer2.crt',
      false => 'swamid-qa.crt',
    }

    file { "/opt/bankidp/config/certificates/${signing_cert}":
      ensure  => 'file',
      mode    => '0755',
      owner   => 'root',
      content => file("sunet/bankidp/${signing_cert}")
    }

    sunet::docker_compose { 'bankidp':
      content          => template('sunet/bankidp/docker-compose-bankid-idp.yml.erb'),
      service_name     => 'bankidp',
      compose_dir      => '/opt/',
      compose_filename => 'docker-compose.yml',
      description      => 'Freja ftw',
    }
  }
  if $redis_node {
    class { 'sunet::rediscluster':
      numnodes         => 2,
      cluster_announce_ip => $facts['ipaddress_default']
    }
  }
}
