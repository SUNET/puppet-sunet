define sunet::nagios::nrpe_check_nrpe_proxy ($display_name = undef, $proxy, $cmd, $opt) {
  sunet::nagios::nrpe_command {$title:
    command_line => "/usr/lib/nagios/plugins/check_nrpe -H ${proxy} -c ${cmd} ${opt}"
  }
}
