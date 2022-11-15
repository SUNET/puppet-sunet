# Write a Redis configuration file.
define sunet::redis::config (
  String            $filename,
  String            $public_ip       = $::facts['ipaddress_default'],
  Integer           $port            = 6379,
  String            $bind            = '0.0.0.0',    # need specific IP, otherwise redis 3.2+ will deny clients
  Enum['yes', 'no'] $protected_mode  = 'yes',
  String            $username        = 'redis',
  String            $group           = 'redis',
  Array             $cluster_nodes   = [],
  Enum['yes', 'no'] $cluster_config  = 'no',
  String            $cluster_name    = 'redis-cluster',
  Enum['yes', 'no'] $sentinel_config = 'no',
  Integer           $sentinel_port   = 26379,
  String            $master_ip       = pick($cluster_nodes[0], $::facts['ipaddress_default']),
) {
  # Configure all nodes as replicaof $master_ip, unless this node actually has $master_ip as $public_ip
  $replica_node = $master_ip ? {
    $public_ip => 'no',
    default    => 'yes',
  }

  if $replica_node == 'yes' {
    notice("Configuring Redis node replicaof ${master_ip} port ${master_port}")
  } else {
    notice("Configuring as Redis master with IP ${master_ip} as public_ip")
  }

  if $sentinel_config == 'yes' {
    notice("Configuring Redis Sentinel to monitor ${master_ip} port ${master_port}")
  }

  file {
    $filename:
      ensure  => 'file',
      mode    => '0640',
      group   => $group,
      content => template('sunet/redis/cluster_node.conf.erb'),
      require => Sunet::System_user[$username],
      force   => true,
      ;
  }
}
