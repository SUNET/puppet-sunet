# Setup Scriptherder on a host
#
# Scriptherder is a wrapper for primarily cron jobs, used to save the execution status and output,
# and allow monitoring of the cron jobs from Nagios or similar.
#
# @param install    Whether to install the bundled scriptherder.py script or not
# @param nrpe       Whether to install the default NRPE checks or not
# @param nrpe_sudo  Run the NRPE check with sudo or not. Needed if umask prevents nagios user from reading check results.
class sunet::scriptherder::init (
  Boolean $install          = true,
  Boolean $nrpe             = true,
  Boolean $nrpe_sudo        = true,
  String  $scriptherder_dir = '/var/cache/scriptherder',
  Integer $keep_days        = hiera('scriptherder_delete_older_than', 6),
) {
  if $install {
    if $::facts['operatingsystem'] == 'Ubuntu' and versioncmp($::facts['operatingsystemrelease'], '18.04') < 0 {
      notice('Not installing Scriptherder on Ubuntu < 18.04 (because of too old Python version)')
    } else {
      file { '/usr/local/bin/scriptherder':
        mode   => '0755',
        source => 'puppet:///modules/sunet/scriptherder/scriptherder.py',
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

  # Remove scriptherder data older than 7 days.
  cron { 'scriptherder_cleanup':
    command => "test -d ${scriptherder_dir} && (find ${scriptherder_dir} -type f -mtime +${keep_days} -print0 | xargs -0 rm -f)",
    user    => 'root',
    special => 'daily',
  }
}
