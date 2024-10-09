# Set up and run Redis
define sunet::redis::server(
  Integer           $port            = 6379,
  String            $bind            = '0.0.0.0',
  Enum['yes', 'no'] $daemonize       = 'no',
  String            $username        = 'redis',
  String            $group           = 'redis',
  Array             $allow_clients   = [],
  Array             $cluster_nodes   = [],
  Enum['yes', 'no'] $cluster_config  = 'no',
  String            $cluster_name    = 'redis-cluster',
  Enum['yes', 'no'] $sentinel_config = 'no',
  String            $master_ip       = pick($cluster_nodes[0], $facts['networking']['interfaces']['default']['ip']),
  Integer           $master_port     = 6379,
  Optional[String]  $docker_image    = 'docker.sunet.se/eduid/redis',
  String            $docker_tag      = 'latest',
  String            $basedir         = "/opt/redis/${name}"
  ) {

  $env = $sentinel_config ? {
    'yes'   => ['extra_args=--sentinel'],
    default => [],
  }

  # Configure all nodes as slaveof $master_ip, unless this node actually has $master_ip on eth0/bond0
  $slave_node = $master_ip ? {
    $facts['networking']['interfaces']['eth0']['ip']    => 'no',
    $facts['networking']['interfaces']['bond0']['ip']   => 'no',
    $facts['networking']['interfaces']['default']['ip'] => 'no',
    default              => 'yes',
  }

  if $slave_node == 'yes' {
    notice("Configuring Redis node slaveof ${master_ip} port ${master_port}")
  } else {
    notice("Configuring as Redis master with IP ${master_ip} on eth0/bond0/default")
  }

  if $sentinel_config == 'yes' {
    notice("Configuring Redis Sentinel to monitor ${master_ip} port ${master_port}")
  }

  sunet::misc::ufw_allow { "${name}_allow_clients":
    from => [ $allow_clients,
              $cluster_nodes,
            ],
    port => $port,
  }

  sunet::misc::ufw_allow { "${name}_allow_cluster_speak":
    from => $cluster_nodes,
    port => $port + 10000,
  }

  ensure_resource('sunet::system_user', $username, {
    username => $username,
    group    => $group,
  })

  file {
    $basedir:
      ensure  => 'directory',
      mode    => '0750',
      group   => $group,
      require => Sunet::System_user[$username],
      ;
    "${basedir}/etc":
      ensure  => 'directory',
      mode    => '0750',
      group   => $group,
      require => Sunet::System_user[$username],
      ;
    "${basedir}/etc/redis.conf":
      ensure  => 'file',
      mode    => '0640',
      group   => $group,
      content => template('sunet/redis/redis.conf.erb'),
      require => Sunet::System_user[$username],
      force   => true,
      ;
    "${basedir}/data":
      ensure  => 'directory',
      mode    => '0770',
      group   => $group,
      require => Sunet::System_user[$username],
      ;
  }

  if $docker_image =~ String[1] {
    sunet::docker_run { $name:
      image    => $docker_image,
      imagetag => $docker_tag,
      net      => 'host',  # Required for Redis clustering/HA
      volumes  => ["${basedir}/etc/redis.conf:/etc/redis/redis.conf",
                  "${basedir}/data:/data",
                  '/dev/log:/dev/log',
                  ],
      env      => flatten($env),
    }
  }
}
