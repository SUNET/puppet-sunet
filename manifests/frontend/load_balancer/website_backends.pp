# website_backends
define sunet::frontend::load_balancer::website_backends(
  Hash   $backends,
  String $basedir,
  String $confdir,
  Array  $backend_haproxy_config,
) {
  # Create backend directory for this website so that the sunetfrontend-api will
  # accept register requests from the servers
  file {
    "${basedir}/api/backends/${name}":
      ensure => 'directory',
      group  => 'sunetfrontend',
      mode   => '0770',
      ;
  }

  # Allow the backend servers for this website to access the sunetfrontend-api
  # to register themselves.
  #
  # OLD
  sunet::misc::ufw_allow { "allow_backends_to_api_${name}":
    from => keys($backends).filter |$k| { is_ipaddr($k) },
    port => '8080',  # port of the sunetfronted-api
  }
  # NEW
  each($backends) | $k, $v | {
    if is_hash($v) {
      sunet::misc::ufw_allow { "allow_backends_to_api_${name}_${k}":
        from => keys($v).filter |$this| { is_ipaddr($this) },
        port => '8080',  # port of the sunetfronted-api
      }
    }
  }

  # 'export' config to a file usable by haproxy-config-update+haproxy-backend-config
  # to create backend configuration
  $export_data = {
    'backends'               => $backends,
    'backend_haproxy_config' => $backend_haproxy_config,
  }
  file { "${confdir}/${name}_backends.yml":
    ensure  => 'file',
    group   => 'sunetfrontend',
    mode    => '0640',
    content => inline_template("<%= @export_data.to_yaml %>\n"),
  }
}
