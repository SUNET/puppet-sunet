# A cluster class
class sunet::rediscluster(
  Integer $numnodes = 3,
  Boolean $hostmode = false,
  Optional[Boolean] $tls = false,
  Optional[String] $cluster_announce_ip = '',
)
{

  # Allow the user to either specify the variable in cosmos-rules or in hiera
  if $cluster_announce_ip == '' {
    $__cluster_announce_ip = lookup('cluster_announce_ip', undef, undef, '')
  } else {
    $__cluster_announce_ip = $cluster_announce_ip
  }
  # Allow the user to use the explicit string ipaddress or ipaddress6 to use the corresponding facts
  if $__cluster_announce_ip == 'ipaddress' {
    $_cluster_announce_ip = $facts['ipaddress']
  } elsif $__cluster_announce_ip == 'ipaddress6' {
    $_cluster_announce_ip = $facts['ipaddress6']
  } else {
    $_cluster_announce_ip = $__cluster_announce_ip
  }

  $redis_password = safe_hiera('redis_password')

  sunet::docker_compose { 'rediscluster_compose':
    content          => template('sunet/rediscluster/docker-compose.yml.erb'),
    service_name     => 'redis',
    compose_dir      => '/opt/',
    compose_filename => 'docker-compose.yml',
    description      => 'Redis Cluster',
  }
  file {'/etc/sysctl.d/55-vm-overcommit.conf':
    ensure  => present,
    content => template('sunet/rediscluster/55-vm-overcommit.conf.erb'),
  }
  file {'/opt/redis-rectify.sh':
    ensure  => present,
    mode    => '0755',
    content => template('sunet/rediscluster/redis-rectify.sh.erb'),
  }

  range(0, $numnodes - 1).each |$i|{
    $clusterportnum = 16379 + $i
    $redisportnum = 6379 + $i

    file { "/opt/redis/node-${i}":
      ensure  => directory,
    }
    -> file { "/opt/redis/node-${i}/server.conf":
      ensure  => present,
      content => template('sunet/rediscluster/server.conf.erb'),
    }
    if $::facts['sunet_nftables_enabled'] == 'yes' or $::facts['dockerhost_advanced_network'] == 'yes' {
      $ports = [$redisportnum, $clusterportnum]
      $ports.each|$port| {
        sunet::nftables::rule { "redis_port_${port}":
          rule => "add rule inet filter input tcp dport ${port} counter accept comment \"allow-redis-${port}\""
        }
      }
    } else {
      sunet::misc::ufw_allow { "redis_port_${i}":
        from => '0.0.0.0/0',
        port => [$redisportnum,$clusterportnum],
      }
    }
  }
}
