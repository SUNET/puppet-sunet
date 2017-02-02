# Wrapper for garethr-docker docker_compose to do SUNET specific things
define sunet::docker_compose(
  String $content,
  String $compose_dir,
  String $description,
  String $service_name,
  String $service_prefix = 'sunet',
) {
  $compose_file = "${compose_dir}/${service_name}/${service_name}.yml"

  # docker-compose uses dirname as project name
  ensure_resource('file', [$compose_dir, "${compose_dir}/${service_name}"], {
      ensure => 'directory',
      mode   => '700',
  })

  ensure_resource('file', $compose_file, {
      ensure  => 'file',
      mode    => '600',
      content => $content,
      require => Class['sunet::dockerhost'],
  })

  sunet::docker_compose_service { "${service_prefix}-${service_name}":
    compose_file => $compose_file,
    description  => $description,
    require      => File[$compose_file],
  }
}
