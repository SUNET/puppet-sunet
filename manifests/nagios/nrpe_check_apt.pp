# Check apt
define sunet::nagios::nrpe_check_apt (
) {
    file { '/usr/lib/nagios/plugins/check_apt-wrapper':
      ensure  => 'file',
      mode    => '0755',
      owner   => 'root',
      content => file('sunet/nagios/check_apt-wrapper')
    }
    sunet::nagios::nrpe_command { 'check_apt':
      command_line => '/usr/lib/nagios/plugins/check_apt-wrapper',
    }
}
