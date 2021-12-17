# OnlyOffice document server
define sunet::onlyoffice::docs(
  String            $basedir          = "/opt/collabora/docs/${name}",
  String            $contact_mail     = 'noc@sunet.se',
  String            $docker_image     = 'collabora/code',
  String            $docker_tag       = 'latest',
  Array[String]     $dns              = [],
  Optional[String]  $external_network = undef,
  String            $hostname         = $::fqdn,
  Integer           $tls_port         = 443,
  ) {

  admin_password = safe_hiera('collabora_admin_password')
  $collabora_conf = ["username=admin","password=${admin_password}","cert_domain=${hostname}", "servername=${hostname}","dictionaries=sv_SE de_DE en_GB en_US es_ES fr_FR it nl pt_BR pt_PT ru"]
  $collabora_extra_params = ["extra_params=--o:num_prespawn_children=10"]
  $collabora_env = flatten([$collabora_conf,$collabora_extra_params])
  sunet::misc::ufw_allow { 'web_ports':
    from => 'any',
    port => [$tls_port],
  }
  exec {"${name}_mkdir_basedir":
    command => "mkdir -p ${basedir}",
    unless  => "/usr/bin/test -d ${basedir}"
  }
  -> sunet::docker_compose { $name:
    content          => template('sunet/collabora/docker-compose.yml.erb'),
    service_name     => 'collabora',
    compose_dir      => '/opt/',
    compose_filename => 'docker-compose.yml',
    description      => 'Collabora CODE Server',
  }
}
