# New kind of website with one docker-compose setup per website
define sunet::frontend::load_balancer::website(
  String $basedir,
  String $confdir,
  Hash   $config
) {
  # 'export' config to a file
  file {
    "${confdir}/${name}":
      ensure  => 'directory',
      group   => 'sunetfrontend',
      mode    => '0750',
      ;
    "${confdir}/${name}/config.yml":
      ensure  => 'file',
      group   => 'sunetfrontend',
      mode    => '0640',
      content => inline_template("# File created from Hiera by Puppet\n<%= @config.to_yaml %>\n"),
      ;
  }

  # Parameters used in frontend/docker-compose_template.erb
  $instance = has_key($config, 'instance') ? {
    true => $config['instance'],
    false => $name,
  }
  $haproxy_image = pick($config['haproxy_image'], 'docker.sunet.se/library/haproxy')
  $haproxy_imagetag = pick($config['haproxy_imagetag'], 'stable')

  sunet::docker_compose { "frontend-${instance}":
    content        => template('sunet/frontend/docker-compose_template.erb'),
    service_prefix => 'frontend',
    service_name   => $instance,
    compose_dir    => "${confdir}/${name}/compose",
    description    => "SUNET frontend setup for ${instance}",
    service_extras => ["ExecStartPost=-${basedir}/scripts/container-network-config ${name}"],
  }
}
