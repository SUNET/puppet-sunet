# OnlyOffice document server
define sunet::collabora::docs(
  String            $basedir          = "/opt/collabora/docs/${name}",
  String            $certdir          = "/opt/collabora/docs/${name}/certs",
  String            $contact_mail     = 'noc@sunet.se',
  String            $docker_image     = 'collabora/code',
  String            $docker_tag       = 'latest',
  String            $domain           = 'sunet.se',
  Array[String]     $dns              = [],
  Array[String]     $extra_hosts      = [],
  Array[String]     $extra_volumes    = [],
  Optional[String]  $external_network = undef,
  String            $hostname         = $facts['networking']['fqdn'],
  Integer           $tls_port         = 443,
  ) {

  $admin_password = safe_hiera('collabora_admin_password')
  $collabora_conf = ['username=admin',"password=${admin_password}","DONT_GEN_SSL_CERT=''", "servername=${hostname}",'dictionaries=sv_SE de_DE en_GB en_US es_ES fr_FR it nl pt_BR pt_PT ru']
  $collabora_extra_params = ['extra_params=--o:welcome.enable=false --o:num_prespawn_children=10 --o:ssl.cert_file_path=/certs/collabora.crt --o:ssl.key_file_path=/certs/collabora.key --o:ssl.ca_file_path=/certs/ca-certificates.crt --o:net.frame_ancestors=https://*']
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
  -> file {[$basedir, $certdir]: ensure => directory }
}

