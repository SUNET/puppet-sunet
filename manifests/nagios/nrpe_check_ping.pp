define sunet::nagios::nrpe_check_ping ($ip, $display_name = undef, $opt = '-w 30.0,3% -c 50.0,5% -n 5 -4') {
  sunet::nagios::nrpe_command {$title:
    command_line => "/usr/lib/nagios/plugins/check_ping -H ${ip} ${opt}"
  }
}
