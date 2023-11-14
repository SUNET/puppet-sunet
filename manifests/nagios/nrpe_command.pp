# nrpe command
define sunet::nagios::nrpe_command ($command_line = undef) {

  if defined('$sunet::nagios::nrpe_service') {
    service = $sunet::nagios::nrpe_service
  } elsif ('$sunet::nagios::nrpe::nrpe_service') {
    service = $sunet::nagios::nrpe::nrpe_service
  }

  concat::fragment {"sunet_nrpe_command_${name}":
    target  => '/etc/nagios/nrpe.d/sunet_nrpe_commands.cfg',
    content => template('sunet/nagioshost/nrpe_command.erb'),
    order   => '30',
    notify  => Service[$service]
  }
}
