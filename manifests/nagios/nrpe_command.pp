import stdlib
import concat

define nrpe_command ($command_line = undef) {
   concat::fragment {"sunet_nrpe_command_${name}":
      target  => "/etc/nagios/nrpe.d/sunet_nrpe_commands.cfg",
      content => template('nagioshost/nrpe_command.erb'),
      order   => '30',
      notify  => $sunet::nagios::nrpe_service
   }
}
