define sunet::nagios::nrpe_check_nrpe ($display_name = undef, $ip, $cmd) {
  sunet::nagios::nrpe_command {$title:
    command_line => "/usr/lib/nagios/plugins/check_nrpe -H ${ip} -c ${cmd}"
  }
}
