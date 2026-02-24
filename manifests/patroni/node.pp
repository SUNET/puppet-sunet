# Setup a a patroni node
class sunet::patroni::node(
  String $patroni_cluster_name = 'batman',
  Integer $patroni_rest_api_port = 8008,
  Integer $postgres_port = 5432,
  String $patroni_imagetag = '4.1.0',
  Boolean $pgbackrest = false,
  String $pgbackrest_backup_host = '',
  String $pgbackrest_user = 'root',
) {

  $myself = $facts['networking']['fqdn'] # Use with connect_addr
  $infra_cert = "/etc/ssl/private/${myself}_infra.pem"
  $postgres_cert = "/opt/patroni/certs/${myself}.pem"
  $etcd_nodes = lookup('etcd_nodes', undef, undef, [])
  $postgres_node_ips = lookup('postgres_node_ips', undef, undef, [])
  $replicator_password = lookup('postgres_replicator_password', undef, undef, 'NOT_SET_IN_HIERA')
  $superuser_password = lookup('postgres_superuser_password', undef, undef, 'NOT_SET_IN_HIERA')
  $rewind_password = lookup('postgres_rewind_password', undef, undef, 'NOT_SET_IN_HIERA')
  $loadbalancer_ips = lookup('loadbalancer_ips', undef, undef, [])
  $pgbackrest_backup_host_ips = lookup('pgbackrest_backup_host_ips', undef, undef, [])

  sunet::nftables::allow { 'allow-lbs':
    from => $loadbalancer_ips,
    port => [$postgres_port, $patroni_rest_api_port],
  }
  sunet::nftables::allow { 'allow-postgres-peers':
    from => $postgres_node_ips,
    port => [$postgres_port,$patroni_rest_api_port],
  }
  ensure_resource('sunet::misc::create_dir', '/opt/patroni/config/', { owner => 'root', group => 'root', mode => '0750'})

  ensure_resource('sunet::misc::create_dir', '/opt/patroni/certs/', { owner  => 'root', group => 'root', mode => '0755'})

  # The patroni image is hardcorded to use a user which we cant override or set correct permissions for.
  if (find_file($infra_cert)) {
    file { $postgres_cert:
        ensure => 'file',
        source => $infra_cert,
        owner  => 'root',
        group  => 'root',
        mode   => '0755',
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

  if ($pgbackrest) {
    # Write the pgbackrest config
    file { '/opt/patroni/config/pgbackrest.conf':
      content => template('sunet/patroni/pgbackrest.conf.erb'),
      mode    => '0755',
    }
    # Allow inbound SSH from backup repo host
    sunet::nftables::allow { 'allow-ssh-pgbackrest-host':
      from => $pgbackrest_backup_host_ips,
      port => "22",
    }
    # Accept hostkey so SSH towards the repo host does not hang
    sunet::ssh_keyscan::host {${pgbackrest_backup_host}: }
    # Accept SSH-key for pgbackrest host
    sunet::ssh_keys { 'pgbackrest_hosts':
      config            => safe_hiera('pggbackrest_host_ssh_keys', {}),
      key_database_name => 'pgbackrest_hosts_db',
    }
    # Generate SSH-key used to access backup repo host
    $key_path = '/root/.ssh/id_ed25519'
    if lookup('pgbackrest_ssh_key', undef, undef, undef) { # Key is in secrets, write it to host
      ensure_resource('sunet::snippets::secret_file', $key_path, {
      hiera_key => 'pgbackrest_ssh_key',
    })
    } else {
      if (!find_file($key_path)){
        sunet::snippets::ssh_keygen{$key_path:} # This will not overwrite an existing key
      }
    }
  }

  sunet::docker_compose { 'patroni':
    content          => template('sunet/patroni/docker-compose-patroni-node.yml.erb'),
    service_name     => 'patroni',
    compose_dir      => '/opt/',
    compose_filename => 'docker-compose.yml',
    description      => 'High availability (HA) PostgreSQL',
  }
}
