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


  ensure_resource('sunet::misc::create_dir', '/opt/geteduroam/var', { owner => 'root', group => 'www-data', mode => '0770'})
  ensure_resource('sunet::misc::create_dir', '/opt/geteduroam/config', { owner => 'root', group => 'root', mode => '0750'})

  file { '/opt/geteduroam/config/letswifi.conf.php':
    content => template('sunet/geteduroam/letswifi.conf.simplesaml.php.erb'),
    mode    => '0755',
  }

  sunet::docker_compose { 'geteduroam':
    content          => template('sunet/geteduroam/docker-compose.yml.erb'),
    service_name     => 'geteduroam',
    compose_dir      => '/opt/',
    compose_filename => 'docker-compose.yml',
    description      => 'geteduroam',
  }

}
