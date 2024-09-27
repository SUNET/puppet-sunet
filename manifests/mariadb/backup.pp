# This is a asyncronous replica of the Maria DB Cluster for SUNET
class sunet::mariadb::backup(
  String $mariadb_version=latest,
  Array[String] $dns = [],
  Boolean $nrpe = true,
) {

  include sunet::packages::netcat_openbsd
  ensure_resource('file',"/opt/mariadb/backup/", { ensure => directory, recurse => true } )
  $dirs = [ 'datadir', 'init', 'conf', 'backups' ]
  $dirs.each | $dir | {
    ensure_resource('file',"/opt/mariadb/backup/${dir}", { ensure => directory, recurse => true } )
  }

  $cluster_nodes = lookup('mariadb_cluster_nodes', undef, undef,[])
  $replicate_from = $cluster_nodes[0]

  # Secrets from local.eyaml
  $mariadb_root_password = safe_hiera('mariadb_root_password')
  $mariadb_backup_password = safe_hiera('mariadb_root_password')
  $mariadb_user_password = safe_hiera('mariadb_user_password')

  sunet::system_user {'mysql': username => 'mysql', group => 'mysql' }

  $sql_files = ['02-backup_user.sql']
  $sql_files.each |$sql_file|{
    file { "/opt/mariadb/backup/init/${sql_file}":
      ensure  => present,
      content => template("sunet/mariadb/${sql_file}.erb"),
      mode    => '0744',
    }
  }
  $conf_files = ['credentials.cnf', 'my.cnf']
  $conf_files.each |$conf_file|{
    file { "/opt/mariadb/conf/${conf_file}":
      ensure  => present,
      content => template("sunet/mariadb/${conf_file}.erb"),
      mode    => '0744',
    }
  }
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
  sunet::sudoer {'nagios_run_replication_command':
    user_name    => 'nagios',
    collection   => 'nrpe_replication_check',
    command_line => '/usr/local/bin/check_replication'
  }
  sunet::nagios::nrpe_command {'check_async_replication':
    command_line => '/usr/bin/sudo /usr/local/bin/check_replication'
  }
  sunet::docker_compose { 'mariadb':
    content          => template('sunet/mariadb/docker-compose_mariadb.yml.erb'),
    service_name     => 'mariadb',
    compose_dir      => '/opt/',
    compose_filename => 'docker-compose.yml',
    description      => 'Mariadb replica',
  }

}
