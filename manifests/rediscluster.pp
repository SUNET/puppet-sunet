# A cluster class
class sunet::rediscluster(
  Integer $numnodes = 3,
)
{
  include stdlib

  sunet::docker_compose { 'rediscluster_compose':
    content          => template('sunet/rediscluster/docker-compose.yml.erb'),
    service_name     => 'redis',
    compose_dir      => '/opt/',
    compose_filename => 'docker-compose.yml',
    description      => 'Redis Cluster',
  }

  range(0, $numnodes - 1).each |$i|{
    $portnum = 7000 + $i

    file { "/opt/redis/node-${i}":
      ensure  => directory,
    }
    -> file { "/opt/redis/node-${i}/server.conf":
      ensure  => present,
      content => template('sunet/rediscluster/server.conf.erb'),
    }
    -> sunet::misc::ufw_allow { "redis_port_${portnum}":
      from => '0.0.0.0/0',
      port => $portnum,
    }
  }
}
