# Setup a a patroni node
class sunet::patroni::node(
  String $patroni_cluster_name = 'batman',
  Integer $patroni_rest_api_port = 8008,
  Integer $postgres_port = 5432,
  String $patroni_imagetag = '4.0.7'
) {

  $myself = $facts['networking']['fqdn'] # Use with connect_addr
  $infra_cert = "/etc/ssl/private/${myself}_infra.pem"
  $postgres_cert = "/opt/patroni/certs/${myself}.pem"
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
    ensure => 'present',
    # Random number that we hope will not interfer with others…
    uid    =>  41227,
  }
  ensure_resource('sunet::misc::create_dir', '/opt/patroni/data/', { owner   => 'patroni-postgres', group => 'root', mode => '0750'})
  ensure_resource('sunet::misc::create_dir', '/opt/patroni/certs/', { owner  => 'patroni-postgres', group => 'root', mode => '0750'})

  # The patroni image is hardcorded to use a user which we cant override or set correct permissions for.
  if (find_file($infra_cert)) {
    file { $postgres_cert:
        ensure => 'file',
        source => $infra_cert,
        owner  => 'patroni-postgres',
        group  => 'patroni-postgres',
    }
  }

  file { '/opt/patroni/config/patroni.yml':
    content => template('sunet/patroni/patroni.yml.erb'),
    mode    => '0755',
  }

  file { '/usr/local/bin/patronictl':
    content => file('sunet/patroni/patronictl'),
    mode    => '0755',
  }

  file { '/usr/local/bin/psql':
    content => template('sunet/patroni/psql.erb'),
    mode    => '0755',
  }

  # Monitoring script that can be executed with NRPE
  file { '/usr/local/sbin/check-patroni-status.py':
    ensure  => 'file',
    mode    => '0755',
    owner   => 'root',
    content => file('sunet/patroni/check-patroni-status.py')
  }
  # NRPE commands file
  file { '/etc/nagios/nrpe.d/nrpe-patroni.cfg':
    ensure  => 'file',
    mode    => '0644',
    owner   => 'root',
    content => file('sunet/patroni/nrpe-patroni.cfg')
  }

  sunet::docker_compose { 'patroni':
    content          => template('sunet/patroni/docker-compose-patroni-node.yml.erb'),
    service_name     => 'patroni',
    compose_dir      => '/opt/',
    compose_filename => 'docker-compose.yml',
    description      => 'High availability (HA) PostgreSQL',
  }
}
