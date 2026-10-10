# Wrapper for garethr-docker docker_compose to do SUNET specific things
define sunet::docker_compose (
  String           $content,
  String           $compose_dir,
  String           $description,
  String           $service_name,
  String           $service_prefix = 'sunet',
  Array[String]    $service_extras = [],
  Boolean          $service_dir_layout = false,
  Optional[String] $compose_filename = undef,
  String           $group = 'root',
  String           $mode = '0700',
  String           $owner = 'root',
  Optional[String] $service_alias = undef,
  Optional[String] $start_command = undef,
) {

  $docker_class = $::facts['dockerhost2'] ? {
    yes => 'sunet::dockerhost2',
    default => 'sunet::dockerhost',
  }
  if ($docker_class == 'sunet::dockerhost') {
    # handle legacy class
    $nftenabled_and_interface =  $::facts['sunet_nftables_enabled'] == 'yes' and has_key($::facts['networking']['interfaces'], 'to_docker')
    $advanced_network_or_nftdisabled = $::facts['dockerhost_advanced_network'] == 'yes' or $::facts['sunet_nftables_enabled'] == 'no'
    if ( $nftenabled_and_interface or  $advanced_network_or_nftdisabled ) {
      $_install_service = true
    } else {
      $_install_service = false
      notice("sunet::docker_compose: Not installing ${service_name}, interface to_docker missing")
    }
  } else {
    $_install_service = true
  }

  if $_install_service {
    if $service_dir_layout {
      # The caller owns ${compose_dir}/${service_name}; we only manage its compose/ subdirectory.
      # The project name can't come from the directory name here, so pin it to the service name.
      $_compose_subdir = "${compose_dir}/${service_name}/compose"
      $_project_name = $service_name
    } else {
      # docker-compose uses dirname as project name, so we add $service_name and put the compose_file in there
      $_compose_subdir = "${compose_dir}/${service_name}"
      $_project_name = undef
    }
    $_compose_filename = $compose_filename ? {
      undef   => $service_dir_layout ? {
        true    => 'docker-compose.yaml',
        default => "${service_name}.yml",
      },
      default => $compose_filename,
    }
    $compose_file = "${_compose_subdir}/${_compose_filename}"

    ensure_resource('sunet::misc::create_dir', [$_compose_subdir], { owner => $owner, group => $group, mode => $mode })

    ensure_resource('file', $compose_file, {
        ensure  => 'file',
        mode    => '600',
        content => $content,
        require => Class[$docker_class],
    })

    sunet::docker_compose_service { "${service_prefix}-${service_name}":
      service_alias  => $service_alias,
      compose_file   => $compose_file,
      description    => $description,
      require        => File[$compose_file],
      service_extras => $service_extras,
      start_command  => $start_command,
      project_name   => $_project_name,
    }
  }
}
