# Get eduroam
class sunet::geteduroam(
  String $domain,
  Array $resolvers = [],
  String $app_tag = 'latest'
){

  if $::facts['sunet_nftables_enabled'] == 'yes' {
      sunet::nftables::docker_expose { 'allow_http' :
      iif           => $interface,
      allow_clients => 'any',
      port          => 80,
    }

      sunet::nftables::docker_expose { 'allow_https' :
      iif           => $interface,
      allow_clients => 'any',
      port          => 443,
    }
  }

  class { 'sunet::dehydrated::client': domain =>  $domain, ssl_links => true }


  sunet::docker_compose { 'geteduroam':
    content          => template('sunet/geteduroam/docker-compose.yml.erb'),
    service_name     => 'geteduroam',
    compose_dir      => '/opt/',
    compose_filename => 'docker-compose.yml',
    description      => 'geteduroam',
  }

}
