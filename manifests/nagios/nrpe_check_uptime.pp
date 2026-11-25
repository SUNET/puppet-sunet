# Check uptime
define sunet::nagios::nrpe_check_uptime (
  Integer $uptimew = 30,
  Integer $uptimec = 50,
) {
  include sunet::nagios::nrpe_paths
  if $facts['os']['name'] == 'AlmaLinux' {
    Package['nagios-plugins'] -> File["${sunet::nagios::nrpe_paths::plugins}/check_uptime.py"]
  }

  $_uptimew = lookup('check_uptime_warning', undef, undef, $uptimew)
  $_uptimec = lookup('check_uptime_critical', undef, undef, $uptimec)

  file { "${sunet::nagios::nrpe_paths::plugins}/check_uptime.pl" :
      ensure  => 'absent',
  }
  file { "${sunet::nagios::nrpe_paths::plugins}/check_uptime.py" :
      ensure  => 'file',
      mode    => '0751',
      group   => $sunet::nagios::nrpe_paths::user,
      require => Package[$sunet::nagios::nrpe_paths::service],
      content => template('sunet/nagioshost/check_uptime.py.erb'),
  }
  sunet::nagios::nrpe_command {'check_uptime':
    command_line => "${sunet::nagios::nrpe_paths::plugins}/check_uptime.py -w ${_uptimew} -c ${_uptimec}"
  }
}
