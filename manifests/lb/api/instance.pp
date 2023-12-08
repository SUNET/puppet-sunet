# Configure API for a frontend instance
define sunet::lb::api::instance(
  String        $site_name,
  Integer       $api_port = 8080,
  Array[String] $backend_ips = [],
  String        $basedir = '/opt/frontend/api',
) {

  if $::facts['sunet_nftables_enabled'] != 'yes' {
    sunet::misc::ufw_allow { "allow_backends_${name}":
      from => $backend_ips,
      port => $api_port,
    }
  }

  # Create backend directory for this website so that the sunetfrontend-api will
  # accept register requests from the servers
  ensure_resource('file', "${basedir}/backends/${site_name}", {
      ensure => 'directory',
      owner  => 'fe-api',
      group  => 'fe-config',
      mode   => '2750',
  })
}
