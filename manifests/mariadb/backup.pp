# This is a asyncronous replica of the Maria DB Cluster for SUNET
class sunet::mariadb::backup(
  String $mariadb_version=latest,
  Array[String] $dns = [],
  Boolean $backup_to_baas = true,
  Boolean $nrpe = true,
) {

  sunet::mariadb { 'sunet_mariadb_simple':
    mariadb_version => $mariadb_version,
    ports           => [3306],
    dns             => $dns,
    galera          => false,
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
  file { '/opt/mariadb/scripts/do_backup.sh':
    ensure  => present,
    content => template('sunet/mariadb/backup/do_backup.erb.sh'),
    mode    => '0744',
  }

  if $backup_to_baas {
    file { '/usr/local/bin/backup2baas':
      ensure  => present,
      content => template('sunet/mariadb/backup/backup2baas.erb'),
      mode    => '0744',
    }

    sunet::scriptherder::cronjob { 'backup2baas':
      cmd           => '/usr/local/bin/backup2baas',
      hour          => '6',
      minute        => '10',
      ok_criteria   => ['exit_status=0', 'max_age=24h'],
      warn_criteria => ['exit_status=1'],
    }
  }

  file { '/usr/lib/nagios/plugins/check_mariadb-replication':
    ensure  => present,
    content => template('sunet/mariadb/backup/check_replication.erb'),
    mode    => '0744',
  }
  file { '/usr/local/bin/mariadb-replication-status':
    ensure  => present,
    content => template('sunet/mariadb/backup/replication-status.erb'),
    mode    => '0744',
  }
  file { '/etc/sudoers.d/99-mariadb-replication-test':
    ensure  => file,
    content => "script ALL=(root) NOPASSWD: /usr/local/bin/mariadb-replication-status",
    mode    => '0440',
    owner   => 'root',
    group   => 'root',
  }

  if $nrpe {
    sunet::sudoer {'nagios_run_replication_command':
      user_name    => 'nagios',
      collection   => 'nrpe_replication_check',
      command_line => '/usr/lib/nagios/plugins/check_mariadb-replication'
    }
    sunet::nagios::nrpe_command {'check_async_replication':
      command_line => '/usr/bin/sudo /usr/lib/nagios/plugins/check_mariadb-replication'
    }
  }

}
