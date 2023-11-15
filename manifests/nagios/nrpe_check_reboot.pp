# Check reboot
define sunet::nagios::nrpe_check_reboot (
) {

  file { '/usr/lib/nagios/plugins/check_reboot' :
      ensure  => 'file',
      mode    => '0751',
      group   => 'nagios',
      require => Package['nagios-nrpe-server'],
      content => template('sunet/nagioshost/check_reboot.erb'),
  }

  sunet::nagios::nrpe_command {'check_reboot':
    command_line => '/usr/lib/nagios/plugins/check_reboot'
  }
}
