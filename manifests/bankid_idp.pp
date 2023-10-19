# Run bankid-idp with compose
class sunet::bankid_idp(
  Array $environments = [],
  Array $resolvers = [],
  Array $volumes = [],
  Array $ports = [],
  String $imagetag='latest',
) {


    file { '/opt/bankid/config/service.yml':
      content => template('sunet/bankid_idp/service.yml.erb'),
      mode    => '0755',
    }


  sunet::docker_compose { 'bankid-idp':
    content          => template('sunet/bankid_idp/docker-compose-bankid-idp.yml.erb'),
    service_name     => 'bankid_idp',
    compose_dir      => '/opt/',
    compose_filename => 'docker-compose.yml',
    description      => 'Freja ftw',
  }
}
