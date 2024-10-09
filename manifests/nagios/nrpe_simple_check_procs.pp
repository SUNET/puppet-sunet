# check_procs
define sunet::nagios::nrpe_simple_check_procs () {
  sunet::nagios::nrpe_command {"check_process_${title}":
    command_line => "/usr/lib/nagios/plugins/check_procs -u root -w 1:1 -a ${title}"
  }
}
