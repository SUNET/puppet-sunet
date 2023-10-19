# Run bankid-idp with compose
class sunet::bankidp(
  Array $environments_extras = [],
  Array $resolvers = [],
  Array $volumes_extras = [],
  Array $ports_extras = [],
  String $imagetag='latest',
  String $spring_profiles_active = 'sandbox',
  String $server_servlet_context_path = '/bankid/idp',
  String $saml_idp_base_url = 'https://sandbox.swedenconnect.se/bankid/idp',
  String $tz = 'Europe/Stockholm',
  String $bankid_home = '/opt/bankidp',
  String $spring_config_import = '/config/service.yml'
) {

    ensure_resource(sunet::misc::create_dir('/opt/bankidp/config/'))
    file { '/opt/bankidp/config/service.yml':
      content => template('sunet/bankidp/service.yml.erb'),
      mode    => '0755',
    }


  sunet::docker_compose { 'bankidp':
    content          => template('sunet/bankidp/docker-compose-bankid-idp.yml.erb'),
    service_name     => 'bankidp',
    compose_dir      => '/opt/',
    compose_filename => 'docker-compose.yml',
    description      => 'Freja ftw',
  }
}
