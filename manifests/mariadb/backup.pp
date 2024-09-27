# This is a asyncronous replica of the Maria DB Cluster for SUNET
class sunet::mariadb::backup(
  String $mariadb_version=latest,
  Array[String] $dns = [],
  Boolean $nrpe = true,
) {

  sunet::mariadb { 'sunet_mariadb_simple':
    mariadb_version => $mariadb_version,
    ports           => [3306],
    dns             => $dns,
  }

  $cluster_nodes = lookup('mariadb_cluster_nodes', undef, undef,[])
  $replicate_from = $cluster_nodes[0]

  # Secrets from local.eyaml
  $mariadb_root_password = safe_hiera('mariadb_root_password')
  $mariadb_backup_password = safe_hiera('mariadb_root_password')
  $mariadb_user_password = safe_hiera('mariadb_user_password')

  file { '/opt/mariadb/scripts/start_replica_from_init.sh':
    ensure  => present,
    content => template('sunet/mariadb/backup/start_replica_from_init.erb.sh'),
    mode    => '0744',
  }
  # XXX trigger needed
  file { '/opt/mariadb/scripts/do_backup.sh':
    ensure  => present,
    content => template('sunet/mariadb/backup/do_backup.erb.sh'),
    mode    => '0744',
  }

  file { '/usr/local/bin/check_replication':
    ensure  => present,
    content => template('sunet/mariadb/backup/check_replication.erb'),
    mode    => '0744',
  }
  file { '/usr/local/bin/status-test':
    ensure  => present,
    content => template('sunet/mariadb/backup/status-test.erb'),
    mode    => '0744',
  }
  file { '/etc/sudoers.d/99-status-test':
    ensure  => file,
    content => "script ALL=(root) NOPASSWD: /usr/local/bin/status-test\n",
    mode    => '0440',
    owner   => 'root',
    group   => 'root',
  }

  if $nrpe {
    sunet::sudoer {'nagios_run_replication_command':
      user_name    => 'nagios',
      collection   => 'nrpe_replication_check',
      command_line => '/usr/local/bin/check_replication'
    }
    sunet::nagios::nrpe_command {'check_async_replication':
      command_line => '/usr/bin/sudo /usr/local/bin/check_replication'
    }
  }

}
