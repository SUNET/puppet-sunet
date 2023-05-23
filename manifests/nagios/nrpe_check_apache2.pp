define sunet::nagios::nrpe_check_apache2 ($display_name = undef, $number_of_processes = '4',) {
   sunet::nagios::nrpe_command {"check_process_${title}":
     command_line => "/usr/lib/nagios/plugins/check_procs -C $title -c $number_of_processes:"
   }
}
