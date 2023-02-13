define sunet::nagios::nrpe_check_dns_zone ($display_name = undef) {
   sunet::nagios::nrpe_command {"check_${title}":
     command_line => "/usr/lib/nagios/plugins/check_dns_zone.pl"
   }
}
