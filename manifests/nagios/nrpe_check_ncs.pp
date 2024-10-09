# nrpe_check_ncs
define sunet::nagios::nrpe_check_ncs ($display_name = undef) {
  sunet::nagios::nrpe_command {"check_process_${title}":
    command_line => "/usr/lib/nagios/plugins/check_procs -u ncs -w 1:1 -a ${title}.smp"
  }
}
