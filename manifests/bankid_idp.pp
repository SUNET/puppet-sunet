# Run bankid-idp with compose
class sunet::bankid_idp(
  Array $environments_extras = [],
  Array $resolvers = [],
  Array $volumes = [],
  Array $ports = [],
  String $imagetag='latest',
  String $spring_profiles_active = 'sandbox',
  String $server_servlet_context_path = '/bankid/idp',
  String $saml_idp_base_url = 'https://sandbox.swedenconnect.se/bankid/idp',
  String $tz = 'Europe/Stockholm',
  String $bankid_home = '/opt/bankid',
  String $spring_config_import = '/config/sandbox.yml'
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
