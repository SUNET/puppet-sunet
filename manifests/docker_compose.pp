# Wrapper for garethr-docker docker_compose to do SUNET specific things
define sunet::docker_compose(
  String        $content,
  String        $compose_dir,
  String        $description,
  String        $service_name,
  String        $service_prefix = 'sunet',
  Array[String] $service_extras = [],
  String        $compose_filename = "${service_name}.yml",
) {
  $compose_file = "${compose_dir}/${service_name}/${compose_filename}"

  # docker-compose uses dirname as project name, so we add $service_name and put the compose_file in there
  ensure_resource('sunet::misc::create_dir', ["${compose_dir}/${service_name}"], { owner => 'root', group => 'root', mode => '0700' })

  ensure_resource('file', $compose_file, {
      ensure  => 'file',
      mode    => '600',
      content => $content,
      require => Class['sunet::dockerhost'],
  })

  sunet::docker_compose_service { "${service_prefix}-${service_name}":
    compose_file   => $compose_file,
    description    => $description,
    require        => File[$compose_file],
    service_extras => $service_extras,
  }
}
