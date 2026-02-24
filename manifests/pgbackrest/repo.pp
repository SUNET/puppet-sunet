# This puppet manifest is used to configure a pgBackRest repo/backup server

# @param pg_stanza                     The name of the stanza https://pgbackrest.org/command.html#command-stanza-create
# @param retention_full_days           The number of days to save full backups
# @param pg_user                       The user that the repo/backup server uses towards the DB nodes
# @param pg_command                    The command to be executed on the remote db host
# @param schedule_full                 How often should we run full backups
# @param schedule_incr                 How often should we run incremental backups
# @param schedule_diff                 How often should we run differential backups
class sunet::pgbackrest::repo (
  String                $pg_stanza,
  Integer               $retention_full_days=14,
  String                $pg_user='postgres',
  String                $pg_command='/usr/local/bin/pgbackrest-docker',
  Enum['daily','none']  $schedule_full='daily',
  Enum['hourly','none'] $schedule_incr='none',
  Enum['hourly','none'] $schedule_diff='none',
) {

  # Install pgBackRest
  include sunet::packages::pgbackrest

  # Get the db node information from parameter or hiera
  $db_nodes = lookup('db_nodes', Hash, undef, {})

  $db_nodes.each | $db_node, $value| {
    # Allow inbound SSH used by DB nodes to send backups
    sunet::nftables::allow { "allow-ssh-${db_node}":
      from => $value['prefixes'],
      port => '22',
    }

    # Accept hostkeys so SSH towards the db nodes does not hang
    sunet::ssh_keyscan::host {${db_node}: }
  }

  # Accept SSH-keys for DB nodes
  sunet::ssh_keys { 'pg_db_nodes':
    config            => safe_hiera('pg_db_nodes_ssh_keys', {}),
    key_database_name => 'pg_db_nodes_db',
  }

  # Generate SSH-key used to access DB nodes
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

  # Create the config file for pgbackrest
  file { '/etc/pgbackrest.conf':
    ensure  => file,
    owner   => 'root',
    group   => 'root',
    mode    => '0644',
    content => template('sunet/pgbackrest/pgbackrest.conf.erb'),
  }

  # Schedules
  case $schedule_full {
    'daily': {
      sunet::scriptherder::cronjob { 'pgbackrest_full_backup':
        cmd         => "pgbackrest --stanza=${pg_stanza} --type=full backup",
        minute      => '10',
        hour        => '4',
        ok_criteria => ['exit_status=0', 'max_age=1d'],
      }
    }
  }

  case $schedule_incr {
    'hourly': {
      sunet::scriptherder::cronjob { 'pgbackrest_incr_backup':
        cmd         => "pgbackrest --stanza=${pg_stanza} --type=incr backup",
        minute      => '50',
        ok_criteria => ['exit_status=0', 'max_age=1d'],
      }
    }
  }

  case $schedule_diff {
    'hourly': {
      sunet::scriptherder::cronjob { 'pgbackrest_diff_backup':
        cmd         => "pgbackrest --stanza=${pg_stanza} --type=diff backup",
        minute      => '50',
        ok_criteria => ['exit_status=0', 'max_age=1d'],
      }
    }
  }

  # Monitoring
  file { '/usr/local/sbin/check-pgbackrest-status':
    ensure  => 'file',
    mode    => '0755',
    owner   => 'root',
    content => file('sunet/pgbackrest/check-pgbackrest-status.py')
  }
  # NRPE commands file
  file { '/etc/nagios/nrpe.d/nrpe-pgbackrest.cfg':
    ensure  => 'file',
    mode    => '0644',
    owner   => 'root',
    content => file('sunet/pgbackrest/nrpe-pgbackrest.cfg')
  }
  # sudo exceptions
  file { '/etc/sudoers.d/sudoers-pgbackrest':
    ensure  => 'file',
    mode    => '0440',
    owner   => 'root',
    content => file('sunet/pgbackrest/sudoers-pgbackrest')
  }

}
