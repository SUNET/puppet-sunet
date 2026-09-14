# Configure Nagios monitoring of scriptherder jobs.
# @param use_sudo  Run NRPE checks with sudo, if scriptherder umask prevents access to job files.
class sunet::scriptherder::monitoring (
  Boolean       $use_sudo = true,
  Array[String] $exclude  = [],
) {
  # used in nagios_nrpe_checks.erb and nagios_nrpe_checks_sudoers.erb
  $scriptherder_check_cmd = $exclude ? {
    []      => '/usr/local/bin/scriptherder --mode check',
    default => "/usr/local/bin/scriptherder --mode check --exclude ${exclude.join(' ')}",
  }
  if $::facts['sunet_has_nrpe_d'] == 'yes' {
    if $use_sudo {
      file {
        '/etc/sudoers.d/nrpe_scriptherder_checks':
          ensure  => file,
          mode    => '0440',
          content => template('sunet/scriptherder/nagios_nrpe_checks_sudoers.erb'),
          ;
      }
    }

    file {
      '/etc/nagios/nrpe.d/sunet_scriptherder_checks.cfg':
        ensure  => 'file',
        content => template('sunet/scriptherder/nagios_nrpe_checks.erb'),
        notify  => Service['nagios-nrpe-server'],
        ;
    }
  }
}
