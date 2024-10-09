# check_openvpn
define sunet::nagios::nrpe_check_openvpn ($display_name = undef) {
  sunet::nagios::nrpe_command {"check_process_${title}":
    command_line => "/usr/lib/nagios/plugins/check_procs -u root -w 1:1 -a ${title}"
  }
}
