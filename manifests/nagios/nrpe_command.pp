# nrpe command
define sunet::nagios::nrpe_command ($command_line = undef) {

  # getvar() (not defined('$class::var')) - defined() on a qualified
  # variable name is evaluation-order dependent and can say "false" even
  # after the class has been declared. getvar() just returns undef when
  # unset, no matter the order.
  $service = pick_default(
    getvar('sunet::nagios::nrpe_service'),
    getvar('sunet::nagios::nrpe::nrpe_service')
  )

  # Don't guess a service name if neither var resolved - only notify
  # when we actually know which service to restart.
  $_notify = $service ? {
    undef   => {},
    default => { 'notify' => Service[$service] },
  }

  concat::fragment {"sunet_nrpe_command_${name}":
    target  => '/etc/nagios/nrpe.d/sunet_nrpe_commands.cfg',
    content => template('sunet/nagioshost/nrpe_command.erb'),
    order   => '30',
    * => $_notify,
  }
}
