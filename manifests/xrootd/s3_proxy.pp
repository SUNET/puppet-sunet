# Postfix for SUNET
class sunet::xrootd::s3_proxy(
  String $environment,
  String $container_image          = 'docker.sunet.se/staas/xrootd-s3-http',
  String $container_tag            = '0.17.0-1',
  String $export                   = '/'
  String $interface                = 'ens3',
  String $port                     = '1094',
)
{

  $hostname = $facts['networking']['fqdn']
  # Config
  $config = lookup($environment)

  # Composefile
  sunet::docker_compose { 'xrootd-s3-http':
    content          => template('sunet/xrootd/s3_proxy/docker-compose.erb.yml'),
    service_name     => 'xrootd-s3-http',
    compose_dir      => '/opt',
    compose_filename => 'docker-compose.yml',
    description      => 'XRootD S3 HTTP',
  }
  sunet::nftables::docker_expose { "xrootd_port_${port}":
    allow_clients => 'any',
    port          => $port,
    iif           => $interface,
  }
  file { '/opt/xrootd-s3-http/config':
    ensure => directory,
  }
  file { '/opt/xrootd-s3-http/config/xrootd-s3-http.cfg':
    ensure  => file,
    content => template('sunet/xrootd/s3_proxy/xrootd-s3-http.cfg.erb'),
  }
  $config['buckets'].each |$bucket| {
    file { "/opt/xrootd-s3-http/config/${bucket['name']}":
      ensure => directory,
    }
    file { "/opt/xrootd-s3-http/config/${bucket['name']}/access-key":
      ensure  => file,
      content => $bucket['access_key'],
    }
    file { "/opt/xrootd-s3-http/config/${bucket['name']}/secret-key":
      ensure  => file,
      content => $bucket['secret_key'],
    }
  }

}
