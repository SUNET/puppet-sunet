# Check uptime
define sunet::nagios::nrpe_check_uptime (
) {

  file { '/usr/lib/nagios/plugins/check_uptime.pl' :
      ensure  => 'file',
      mode    => '0751',
      group   => 'nagios',
      require => Package['nagios-nrpe-server'],
      content => template('sunet/nagioshost/check_uptime.pl.erb'),
  }
  sunet::nagios::nrpe_command {'check_uptime':
    command_line => '/usr/lib/nagios/plugins/check_uptime.pl -f'
  }
}
