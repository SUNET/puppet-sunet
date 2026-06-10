# Mariadb cluster class for SUNET
define sunet::mariadb(
  String $mariadb_version          = latest,
  String $mariadb_image            = 'docker.sunet.se/drive/mariadb',
  Boolean $new_cluster             = false, # applies to maridb images from dockerhub.io
  Boolean $docker_healthcheck      = false, # Read here https://wiki.sunet.se/spaces/sunetops/pages/314212754/Mariadb on how to setup the healthcheck
  Array[Integer] $ports            = [3306, 4444, 4567, 4568],
  Array[String] $dns               = [],
  Boolean $galera                  = true,
  Boolean $use_tls                 = false,
  Boolean $nagios_monitoring       = false,
  String  $innodb_buffer_pool_size = '4G',
  String  $ca_cert_path            = '/etc/ssl/certs/infra-2-prod.crt',
)
{

  $mariadb_root_password = lookup('mariadb_root_password', undef, undef,'NOT_SET_IN_HIERA')
  $mariadb_user = lookup('mariadb_user', undef, undef,undef)
  $mariadb_user_password = lookup('mariadb_user_password', undef, undef,undef)
  $mariadb_database = lookup('mariadb_database', undef, undef,undef)
  $mariadb_backup_password = lookup('mariadb_root_password', undef, undef,'NOT_SET_IN_HIERA')
  $clients = lookup('mariadb_clients', undef, undef,['127.0.0.1'])
  $cluster_nodes = lookup('mariadb_cluster_nodes', undef, undef,[])
  $mariadb_dir = '/opt/mariadb'

  # Hack to not clash with docker_compose which tries to create the same directory
  exec {'mariadb_dir_create':
    command => "mkdir -p ${mariadb_dir}",
    unless  =>  "test -d ${mariadb_dir}",
    }

  $dirs = ['datadir', 'init', 'conf', 'backups', 'scripts' ]
  $dirs.each |$dir| {
    ensure_resource('file',"${mariadb_dir}/${dir}", { ensure => directory, recurse => true } )
  }

  if $use_tls {
    # Create cert dir where the TLS certs will be stored
    file { "${mariadb_dir}/cert":
      ensure => directory,
      mode   => '0750',
      owner  => '999',
      group  => '999',
    }
    # Copy the certbot deploy hook
    file { '/etc/letsencrypt/renewal-hooks/deploy/mariadb':
      ensure  => file,
      mode    => '0700',
      content => file('sunet/mariadb/certbot-renewal-hook'),
    }
  }

  $_from = $clients + $cluster_nodes
  sunet::misc::ufw_allow { 'mariadb_ports':
    from => $_from,
    port => $ports,
  }

  file { '/usr/local/bin/purge-binlogs':
    ensure  => present,
    content => template('sunet/mariadb/purge-binlogs.erb.sh'),
    mode    => '0744',
    owner   => 999,
    group   => 999,
  }
  file { '/usr/local/bin/run_manual_backup_dump':
    ensure  => present,
    content => template('sunet/mariadb/run_manual_backup_dump.erb.sh'),
    mode    => '0744',
    owner   => 999,
    group   => 999,
  }
  sunet::scriptherder::cronjob { 'purge_binlogs':
    cmd           => '/usr/local/bin/purge-binlogs',
    hour          => '6',
    minute        => '0',
    ok_criteria   => ['exit_status=0','max_age=2d'],
    warn_criteria => ['exit_status=1','max_age=3d'],
  }
  file { '/usr/local/bin/mariadb-galera-size':
    ensure  => present,
    content => template('sunet/mariadb/cluster-size.erb.sh'),
    mode    => '0744',
  }
  file { '/usr/local/bin/mariadb-galera-status':
    ensure  => present,
    content => template('sunet/mariadb/cluster-status.erb.sh'),
    mode    => '0744',
  }
  file { '/etc/sudoers.d/99-cluster-size-test':
    ensure  => file,
    content => "script ALL=(root) NOPASSWD: /usr/local/bin/mariadb-galera-size\n",
    mode    => '0440',
    owner   => 'root',
    group   => 'root',
  }
  file { '/etc/sudoers.d/99-cluster-status-test':
    ensure  => file,
    content => "script ALL=(root) NOPASSWD: /usr/local/bin/mariadb-galera-status\n",
    mode    => '0440',
    owner   => 'root',
    group   => 'root',
  }

  $sql_files = ['02-backup_user.sql']
  $sql_files.each |$sql_file|{
    file { "${mariadb_dir}/init/${sql_file}":
      ensure  => present,
      content => template("sunet/mariadb/${sql_file}.erb"),
      mode    => '0744',
    }
  }
  file { "${mariadb_dir}/conf/credentials.cnf":
    ensure  => present,
    content => template('sunet/mariadb/credentials.cnf.erb'),
    mode    => '0744',
  }

  $server_id = ipv4_to_int($facts['networking']['ip'])
  file { "${mariadb_dir}/conf/my.cnf":
    ensure  => present,
    content => template('sunet/mariadb/my.cnf.erb'),
    mode    => '0744',
  }
  $docker_compose = sunet::docker_compose { 'sunet_mariadb_docker_compose':
    content          => template('sunet/mariadb/docker-compose_mariadb.yml.erb'),
    service_name     => 'mariadb',
    compose_dir      => '/opt/',
    compose_filename => 'docker-compose.yml',
    description      => 'Mariadb server',
  }
# Monitoring script that can be executed with NRPE
  if $nagios_monitoring {
    file { '/usr/lib/nagios/plugins/check_galera_cluster':
      ensure  => 'file',
      mode    => '0755',
      owner   => 'root',
      content => file('sunet/mariadb/check_galera_cluster')
    }
    # sudo exceptions
    sunet::sudoer {'nrpe_galera_check':
      user_name    => 'nagios',
      collection   => 'nrpe_galera_check',
      command_line => '/usr/lib/nagios/plugins/check_galera_cluster'
    }
    # NRPE command confiruation
    sunet::nagios::nrpe_command {'check_galera_cluster':
      command_line => '/usr/bin/sudo /usr/lib/nagios/plugins/check_galera_cluster'
    }
  }
}
