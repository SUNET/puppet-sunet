# Check uptime
define sunet::nagios::nrpe_check_uptime (
  Integer $uptimew = 30,
  Integer $uptimec = 50,
) {

  $__uptimew = lookup('check_uptime_warning'),
  $_uptimew = $__uptimew ? {
    undef => $uptimew,
    default => $__uptimew,
  }
  $__uptimec = lookup('check_uptime_critical'),
  $_uptimec = $__uptimec ? {
    undef => $uptimec,
    default => $__uptimec,
  }

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
    command_line => "/usr/lib/nagios/plugins/check_uptime.py -w ${_uptimew} -c ${_uptimec}"
  }
}
