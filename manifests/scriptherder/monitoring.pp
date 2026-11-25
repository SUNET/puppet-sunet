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
  include sunet::nagios::nrpe_paths
  $nrpe_user = $sunet::nagios::nrpe_paths::user
  $nrpe_service = $sunet::nagios::nrpe_paths::service
  if defined(Class['sunet::nagios::nrpe']) or $::facts['sunet_has_nrpe_d'] == 'yes' {
    if $facts['os']['name'] == 'AlmaLinux' and $facts.dig('os', 'selinux', 'enabled') {
      include sunet::scriptherder::selinux
    }
    if $use_sudo {
      if $facts['os']['name'] == 'AlmaLinux' and $facts.dig('os', 'selinux', 'enabled') {
        # EL confines the daemon in nrpe_t. Sudoers still restricts its commands.
        selboolean { 'nagios_run_sudo':
          value      => on,
          persistent => true,
          require    => Package[$nrpe_service],
        }
      }
      file {
        '/etc/sudoers.d/nrpe_scriptherder_checks':
          ensure  => file,
          mode    => '0440',
          content => template('sunet/scriptherder/nagios_nrpe_checks_sudoers.erb'),
          ;
      }
    }

    file {
      "${sunet::nagios::nrpe_paths::confdir}/sunet_scriptherder_checks.cfg":
        ensure  => 'file',
        content => template('sunet/scriptherder/nagios_nrpe_checks.erb'),
        require => Package[$nrpe_service],
        notify  => Service[$nrpe_service],
        ;
    }
  }
}
