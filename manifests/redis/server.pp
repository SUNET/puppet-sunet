# Set up and run Redis
define sunet::redis::server(
  $port            = '6379',
  $bind            = '0.0.0.0',
  $daemonize       = 'no',
  $username        = 'redis',
  $group           = 'redis',
  $allow_clients   = [],
  $cluster_nodes   = [],
  $cluster_config  = 'no',
  $cluster_name    = 'redis-cluster',
  $sentinel_config = 'no',
  $master_ip       = pick($cluster_nodes[0], $::ipaddress_eth0, $::ipaddress_bond0),
  $master_port     = '6379',
  $docker_image    = 'docker.sunet.se/eduid/redis',
  $basedir         = "/opt/redis/${name}"
  ) {

  $env = $sentinel_config ? {
    'yes' => ['extra_args=--sentinel'],
    default => [],
  }

  # Configure all nodes as slaveof $master_ip, unless this node actually has $master_ip on eth0/bond0
  $slave_node = $master_ip ? {
    $::ipaddress_eth0  => 'no',
    $::ipaddress_bond0 => 'no',
    default            => 'yes',
  }

  sunet::misc::ufw_allow { "${name}_allow_clients":
    from => [$allow_clients,
             $cluster_nodes,
             ],
    port => $port,
  }

  sunet::misc::ufw_allow { "${name}_allow_cluster_speak":
    from => $cluster_nodes,
    port => sprintf('%s', $port + 10000),
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
      mode    => '640',
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
  } ->

  eduid::docker_run { $name:
    image        => $docker_image,
    imagetag     => 'latest',
    net          => 'host',  # Required for Redis clustering/HA
    volumes      => ["${basedir}/etc/redis.conf:/etc/redis/redis.conf:ro",
                     "${basedir}/data:/data",
                     '/dev/log:/dev/log',
                     ],
    env          => flatten($env),
  }
}
