# Run bankid-idp with compose
class sunet::bankid_idp(
  Array $environments = [],
  Array $resolvers = [],
  Array $volumes = [],
  Integer $port = 443,
  String $imagetag='latest',
) {


  sunet::docker_compose { 'bankid-idp':
    content          => template('sunet/bankid_idp/docker-compose-bankid-idp.yml.erb'),
    service_name     => 'pyff',
    compose_dir      => '/opt/',
    compose_filename => 'docker-compose.yml',
    description      => 'Freja ftw',
  }
}
