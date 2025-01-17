# Check uptime
define sunet::nagios::nrpe_check_uptime (
  Integer $uptimew = 30,
  Integer $uptimec = 50,
) {


  $_uptimew = lookup('check_uptime_warning', undef, undef, $uptimew)
  $_uptimec = lookup('check_uptime_critical', undef, undef, $uptimec)
  file { '/usr/lib/nagios/plugins/check_uptime.pl' :
      ensure  => 'absent',
  }
  file { '/usr/lib/nagios/plugins/check_uptime.py' :
      ensure  => 'file',
      mode    => '0751',
      group   => 'nagios',
      require => Package['nagios-nrpe-server'],
      content => template('sunet/nagioshost/check_uptime.py.erb'),
  }
  sunet::nagios::nrpe_command {'check_uptime':
    command_line => "/usr/lib/nagios/plugins/check_uptime.py -w ${uptimew} -c ${uptimec}"
  }
}
