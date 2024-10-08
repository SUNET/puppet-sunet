define sunet::redis::haproxy(
  $username        = 'redis',
  $group           = 'redis',
  $cluster_nodes   = [],
  $certificate     = undef,
  $client_ca       = undef,
  $port            = '6380',
  $cluster_port    = '6379',
  $basedir         = '/opt/redis'
)
{
  ensure_resource('sunet::system_user', $username, {
      username => $username,
      group    => $group,
  })

  file { ["${basedir}/${name}", "${basedir}/${name}/etc"]:
      mode    => '0750',
      group   => $group,
      require => Sunet::System_user[$username],
      ensure  => directory
  }
  file { "${basedir}/${name}/etc/haproxy.cfg":
      ensure  => 'file',
      mode    => '0640',
      group   => $group,
      require => Sunet::System_user[$username],
      force   => true,
      content => template('sunet/redis/haproxy.cfg.erb')
  }
  -> sunet::docker_run { $name:
      image    => 'docker.sunet.se/library/haproxy',
      imagetag => 'stable',
      ports    => ["${port}:${port}",'127.0.0.1:9000:9000'],
      volumes  => ["${basedir}/${name}/etc/haproxy.cfg:/etc/haproxy/haproxy.cfg:ro",
                  "${certificate}:/etc/ssl/certificate.pem:ro",
                  "${client_ca}:/etc/ssl/client_ca.pem:ro"]
  }

  sunet::misc::ufw_allow { "${name}_allow_redis_ha":
      from => 'any',
      port => $port
  }
}
