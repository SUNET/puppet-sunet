# Setup a a patroni node
class sunet::patroni::node(
  String $patroni_cluster_name = 'batman',
  Integer $patroni_rest_api_port = 8008,
  Integer $postgres_port = 5432,
  String $patroni_imagetag = 'latest'
) {

  $myself = $facts['networking']['fqdn'] # Use with connect_addr
  $etcd_nodes = lookup('etcd_nodes', undef, undef, [])
  $postgres_nodes = lookup('postgres_nodes', undef, undef, [])
  $replicator_password = lookup('postgres_replicator_password', undef, undef, 'NOT_SET_IN_HIERA')
  $superuser_password = lookup('postgres_superuser_password', undef, undef, 'NOT_SET_IN_HIERA')
  $rewind_password = lookup('postgres_rewind_password', undef, undef, 'NOT_SET_IN_HIERA')
  $loadbalancer_ips = lookup('loadbalancer_ips', undef, undef, [])

  sunet::nftables::allow { 'allow-lbs':
    from => $loadbalancer_ips,
    port => [$postgres_port, $patroni_rest_api_port],
  }
  ensure_resource('sunet::misc::create_dir', '/opt/patroni/config/', { owner => 'root', group => 'root', mode => '0750'})

  user {'patroni-postgres':
    ensure => 'present'
  }
  ensure_resource('sunet::misc::create_dir', '/opt/patroni/data/', { owner => 'patroni-postgres', group => 'root', mode => '0750'})
  file { '/opt/patroni/config/patroni.yml':
    content => template('sunet/patroni/patroni.yml.erb'),
    mode    => '0755',
  }
  sunet::docker_compose { 'patroni':
    content          => template('sunet/patroni/docker-compose-patroni-node.yml.erb'),
    service_name     => 'patroni',
    compose_dir      => '/opt/',
    compose_filename => 'docker-compose.yml',
    description      => 'High availability (HA) PostgreSQL',
  }
}
