# Check process command
class sunet::nagios::nrpe_check_process_command (
) {
  file { '/usr/lib/nagios/plugins/check_process' :
    ensure  => 'file',
    mode    => '0751',
    group   => 'nagios',
    require => Package['nagios-nrpe-server'],
    content => template('sunet/nagioshost/check_process.erb'),
  }
}
