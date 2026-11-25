# nrpe command
define sunet::nagios::nrpe_command ($command_line = undef) {

  include sunet::nagios::nrpe_paths
  if defined('$sunet::nagios::nrpe_service') {
    $service = $sunet::nagios::nrpe_service
  } elsif defined('$sunet::nagios::nrpe::nrpe_service') {
    $service = $sunet::nagios::nrpe::nrpe_service
  }

  if defined('$service') {
    concat::fragment {"sunet_nrpe_command_${name}":
      target  => "${sunet::nagios::nrpe_paths::confdir}/sunet_nrpe_commands.cfg",
      content => template('sunet/nagioshost/nrpe_command.erb'),
      order   => '30',
      notify  => Service[$service]
    }
  }
}
