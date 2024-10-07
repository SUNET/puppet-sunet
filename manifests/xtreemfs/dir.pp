# Postfix for SUNET
class sunet::xtreemfs::dir(
  $interface = 'ens3',
  $image = 'docker.sunet.se/staas/xtreemfs-dir',
  $tag = '1.5.1-sunet-1',
  $cert_domain = 'fs.sunet.se',
)
{


  $config = lookup($environment)
  # Composefile
  sunet::docker_compose { 'xtreemfs_dir_server':
    content          => template('sunet/xtreemfs/dir/docker-compose.erb.yml'),
    service_name     => 'xtreemfs_dir_server',
    compose_dir      => '/opt',
    compose_filename => 'docker-compose.yml',
    description      => 'XtreemFS Directory Server',
  }
  $open_ports = [30638,32638]
  $open_ports.each|$port| {
    sunet::nftables::docker_expose { "xtreemfs_port_${port}":
      allow_clients => 'any',
      port          => $port,
      iif           => $interface,
    }
  }
  $dirs = ['/opt/xtreemfs_dir_server/config', '/opt/xtreemfs_dir_server/config/truststore', '/opt/xtreemfs_dir_server/config/truststore/certs', '/opt/xtreemfs_dir_server/data']
  $dirs.each|$dir| {
    file { $dir:
      ensure => directory,
    }
  }
  $config_files = [
    'dirconfig.properties',
  ]
  $config_files.each |$file| {
    file { "/opt/xtreemfs_dir_server/config/${file}":
      ensure  => file,
      content =>  template("sunet/xtreemfs/dir/${file}.erb")
    }
  }

  $keystore = '/opt/xtreemfs_dir_server/config/truststore/certs/ds.p12'
  $cert = "/etc/dehydrated/certs/${cert_domain}/fullchain.pem"
  $key = "/etc/dehydrated/certs/${cert_domain}/privkey.pem"
  exec { 'xtreemfs_dir_server_keystore':
    creates => $keystore,
    cmd     =>  "openssl pkcs12 -export -in ${cert} -inkey ${key} -out ${keystore} -name DS",
    unless  => "test -f ${keystore}"
  }

}
