# Postfix for SUNET
class sunet::xrootd(
  Array[Hash] $cms_allow_hosts,
  Array       $managers,
  String      $manager_domain,
  String      $cms_port                 = '1213',
  String      $container_image          = 'docker.sunet.se/staas/xrootd-s3-http',
  String      $container_tag            = '0.17.0-1',
  String      $export                   = '/',
  String      $interface                = 'ens3',
  String      $xrootd_port              = '1094',
  String      $xrootd_admin_path        = '/var/spool/xrootd',
)
{

  $hostname = $facts['networking']['fqdn']

  if ($hostname in $managers ) {
    $role = 'manager'
  } else {
    $role = 'server'
  }
  # Config
  $xrootd_buckets = lookup('xrootd_buckets')

  # Composefile
  sunet::docker_compose { 'xrootd':
    content          => template('sunet/xrootd/docker-compose.erb.yml'),
    service_name     => 'xrootd',
    compose_dir      => '/opt',
    compose_filename => 'docker-compose.yml',
    description      => 'XRootD S3 HTTP',
  }
  sunet::nftables::docker_expose { "xrootd_port_${xrootd_port}":
    allow_clients => 'any',
    port          => $xrootd_port,
    iif           => $interface,
  }
  if $role == 'server' {
    $cms_ports = '32768-60999'
  } else {
    $cms_ports = $cms_port
  }
  $cms_allow_hosts.each |$host| {
    sunet::nftables::docker_expose { "cms_ports_${host['name']}":
      allow_clients => [$host['ipv4'], $host['ipv6']],
      port          => $cms_ports,
      iif           => $interface,
    }
  }
  file { '/opt/xrootd/config':
    ensure => directory,
    owner  => '100',
    group  => '101',
  }
  file { '/opt/xrootd/admin':
    ensure => directory,
    owner  => '100',
    group  => '101',
  }
  file { '/opt/xrootd/config/xrootd.cfg':
    ensure  => file,
    content => template("sunet/xrootd/xrootd-${role}.cfg.erb"),
  }
  $xrootd_buckets.each |$bucket| {
    file { "/opt/xrootd/config/${bucket['name']}":
      ensure => directory,
    }
    file { "/opt/xrootd/config/${bucket['name']}/access-key":
      ensure  => file,
      content => $bucket['access_key'],
    }
    file { "/opt/xrootd/config/${bucket['name']}/secret-key":
      ensure  => file,
      content => $bucket['secret_key'],
    }
  }

}
