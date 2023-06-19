# Mariadb cluster class for SUNET
class sunet::mariadb(
  String $wsrep_cluster_address,
  Array[String] $client_ips,
  Integer $id,
  String $image= 'mariadb:11',
  String $interface = 'ens3',
)
{

  $cluster_id = 1000 + $id
  $mysql_root_password = lookup('mysql_root_password')
  $mysql_backup_password = lookup('mysql_backup_password')
  $mariadb_dir = '/opt/mariadb'
  $ports = [3306, 4444, 4567, 4568]

  if $::facts['sunet_nftables_enabled'] == 'yes' {
    $ports.each |$port| {
      sunet::nftables::docker_expose { "mariadb_${port}_port" :
        iif           => $interface,
        allow_clients => $client_ips,
        port          => $port,
      }
    }
  } else {
    sunet::misc::ufw_allow { 'mariadb_ports':
      from => $client_ips,
      port => $ports,
    }
  }
  sunet::system_user {'mysql': username => 'mysql', group => 'mysql' }


  file { "${mariadb_dir}/conf/credentials.cnf":
    ensure  => present,
    content => template('sunet/mariadb/credentials.cnf.erb'),
    mode    => '0744',
  }
  file { "${mariadb_dir}/conf/my.cnf":
    ensure  => present,
    content => template('sunet/mariadb/my.cnf.erb'),
    mode    => '0744',
  }
  file { '/usr/local/bin/purge-binlogs':
    ensure  => present,
    content => template('sunet/mariadb/purge-binlogs.erb.sh'),
    mode    => '0744',
  }
  file { "${mariadb_dir}/scripts/run_manual_backup_dump.sh":
    ensure  => present,
    content => template('sunet/mariadb/run_manual_backup_dump.erb.sh'),
    mode    => '0744',
  }
  file { "${mariadb_dir}/scripts/entrypoint.sh":
    ensure  => present,
    content => template('sunet/mariadb/entrypoint.erb.sh'),
    mode    => '0744',
  }
  sunet::scriptherder::cronjob { 'purge_binlogs':
    cmd           => '/usr/local/bin/purge-binlogs',
    hour          => '6',
    minute        => '0',
    ok_criteria   => ['exit_status=0','max_age=2d'],
    warn_criteria => ['exit_status=1','max_age=3d'],
  }
  file { '/usr/local/bin/cluster-size':
    ensure  => present,
    content => template('sunet/mariadb/cluster-size.erb.sh'),
    mode    => '0744',
  }
  file { '/usr/local/bin/cluster-status':
    ensure  => present,
    content => template('sunet/mariadb/cluster-status.erb.sh'),
    mode    => '0744',
  }
  file { '/etc/sudoers.d/99-size-test':
    ensure  => file,
    content => "script ALL=(root) NOPASSWD: /usr/local/bin/cluster-size\n",
    mode    => '0440',
    owner   => 'root',
    group   => 'root',
  }
  file { '/etc/sudoers.d/99-status-test':
    ensure  => file,
    content => "script ALL=(root) NOPASSWD: /usr/local/bin/cluster-status\n",
    mode    => '0440',
    owner   => 'root',
    group   => 'root',
  }
  $podman_compose = sunet::podman_compose { 'mariadb_podman_compose':
    content          => template('sunet/mariadb/podman-compose.yml.erb'),
    service_name     => 'mariadb',
    compose_dir      => '/opt/',
    compose_filename => 'podman-compose.yml',
    description      => 'Mariadb server',
  }
  $dirs = ['datadir', 'init', 'conf', 'backups', 'scripts' ]
  $dirs.each |$dir| {
    ensure_resource('file',"${mariadb_dir}/${dir}", { ensure => directory, owner => 'mysql', group => 'mysql' } )
  }
}
