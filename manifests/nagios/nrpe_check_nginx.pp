# check_process_nginx
define sunet::nagios::nrpe_check_nginx ($display_name = undef) {
  sunet::nagios::nrpe_command {"check_process_${title}":
    command_line => "/usr/lib/nagios/plugins/check_procs -C ${title} -c 2:"
  }
}
