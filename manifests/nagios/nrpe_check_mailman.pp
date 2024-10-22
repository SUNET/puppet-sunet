# check_mailman
define sunet::nagios::nrpe_check_mailman ($display_name = undef) {
  sunet::nagios::nrpe_command {"check_process_${title}":
    command_line => "/usr/lib/nagios/plugins/check_procs -u list -a ${title} -c 9:"
  }
}
