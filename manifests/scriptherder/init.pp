# Setup Scriptherder on a host
#
# Scriptherder is a wrapper for primarily cron jobs, used to save the execution status and output,
# and allow monitoring of the cron jobs from Nagios or similar.
#
# @param install    Whether to install the bundled scriptherder.py script or not
# @param nrpe       Whether to install the default NRPE checks or not
# @param nrpe_sudo  Run the NRPE check with sudo or not. Needed if umask prevents nagios user from reading check results.
class sunet::scriptherder::init (
  Boolean $install                  = true,
  Boolean $nrpe                     = true,
  Boolean $nrpe_sudo                = true,
  String  $scriptherder_dir         = '/var/cache/scriptherder',
  Integer $keep_days                = lookup('scriptherder_delete_older_than', Integer, undef, 6),
  Enum['present', 'absent'] $ensure = 'present',
) {
  if $install {
    if $facts['os']['name'] == 'Ubuntu' and versioncmp($facts['os']['release']['full'], '18.04') < 0 {
      notice('Not installing Scriptherder on Ubuntu < 18.04 (because of too old Python version)')
    } else {
      file { '/usr/local/bin/scriptherder':
        mode   => '0755',
        source => 'puppet:///modules/sunet/scriptherder/scriptherder.py',
      }
      file { '/etc/bash_completion.d/scriptherder-tab-completion.sh':
        mode   => '0755',
        source => 'puppet:///modules/sunet/scriptherder/scriptherder-tab-completion.sh',
      }
    }
  }
  if $nrpe {
    ensure_resource('class', 'sunet::scriptherder::monitoring', {
        use_sudo => $nrpe_sudo,
    })
  }

  file {
    '/etc/scriptherder':
      ensure => 'directory',
      mode   => '0755',
      ;
    '/etc/scriptherder/check':
      ensure => 'directory',
      mode   => '0755',
      ;
    $scriptherder_dir:
      ensure => 'directory',
      mode   => '1777',    # like /tmp, so user-cronjobs can also use scriptherder
      ;
  }

  # Create a default /etc/scriptherder/check/cosmos.ini if cosmos is wrapped in
  # scriptherder, no cosmos.ini is already available and scriptherder is
  # available or about to be installed.
  if $::facts['cosmos_cron_wrapper_available'] and ! $::facts['local_cosmos_ini_available'] and ( $::facts['scriptherder_available'] or $install) {
    $scriptherder_ok   = 'exit_status=0, max_age=8h'
    $scriptherder_warn = 'exit_status=0, max_age=24, OR_file_exists=/etc/no-automatic-cosmos'

    $_file_ensure = $ensure ? {
      'present' => 'file',
      'absent'  => 'absent',
    }

    file { '/etc/scriptherder/check/cosmos.ini' :
      ensure  => $_file_ensure,
      mode    => '0644', # to allow NRPE to read it
      group   => 'root',
      content => template('sunet/scriptherder/scriptherder_check.ini.erb'),
    }
  }

  # Remove scriptherder data older than 7 days.
  cron { 'scriptherder_cleanup':
    command => "test -d ${scriptherder_dir} && (find ${scriptherder_dir} -type f -mtime +${keep_days} -print0 | xargs -0 rm -f)",
    user    => 'root',
    special => 'daily',
  }
}
