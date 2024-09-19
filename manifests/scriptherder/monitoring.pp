# Configure Nagios monitoring of scriptherder jobs.
# @param use_sudo  Run NRPE checks with sudo, if scriptherder umask prevents access to job files.
class sunet::scriptherder::monitoring (
  Boolean $use_sudo = true,
) {
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
