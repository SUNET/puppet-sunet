# Set up and run Redis in a server+sentinel configuration using Docker compose.
define sunet::redis::cluster_node (
  String           $public_ip       = $::facts['ipaddress_default'],
  Integer          $public_port     = 6379,
  Array            $allow_clients   = [],
  Array            $cluster_nodes   = [],
  String           $master_ip       = pick($cluster_nodes[0], $::facts['ipaddress_default']),
  Optional[String] $docker_image    = undef,
  String           $docker_tag      = 'latest',
  String           $basedir         = "/opt/redis/${name}",
  String           $compose_dir     = '/opt/sunet/compose',
  Integer          $sentinel_port   = 26379,
) {
  $username = 'redis'
  $group = 'redis'

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
    "${basedir}/data":
      ensure  => 'directory',
      mode    => '0770',
      group   => $group,
      require => Sunet::System_user[$username],
      ;
  }

  # Write a configuration file for the redis-server
  sunet::redis::config { 'server':
    filename        => "${basedir}/etc/redis-server.conf",
    cluster_nodes   => $cluster_nodes,
    public_ip       => $public_ip,
    public_port     => $public_port,
    sentinel_config => 'no',
    sentinel_port   => $sentinel_port,
  }

  # Write a configuration file for the redis-sentinel
  sunet::redis::config { 'sentinel':
    filename        => "${basedir}/etc/redis-sentinel.conf",
    cluster_nodes   => $cluster_nodes,
    public_ip       => $public_ip,
    public_port     => $public_port,
    sentinel_config => 'yes',
    sentinel_port   => $sentinel_port,
  }

  if $docker_image {
    sunet::docker_compose { $name:
      service_name => 'redis',
      description  => 'Redis database',
      compose_dir  => $compose_dir,
      content      => template('sunet/redis/docker-compose_cluster_node.yml.erb'),
    }

    if $::facts['sunet_nftables_opt_in'] == 'yes' or ( $::facts['operatingsystem'] == 'Ubuntu' and
    versioncmp($::facts['operatingsystemrelease'], '22.04') >= 0 ) {
      sunet::nftables::docker_expose { 'redis-server' :
        allow_clients => $allow_clients,
        port          => 6379,
        allow_local   => true,
      }

      sunet::nftables::docker_expose { 'redis-sentinel' :
        allow_clients => $cluster_nodes,
        port          => 26379,
      }
    }
  }
}
