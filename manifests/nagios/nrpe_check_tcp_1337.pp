# check_tcp_1337
define sunet::nagios::nrpe_check_tcp_1337 ($display_name = undef) {
  sunet::nagios::nrpe_command {"check_tcp_${title}":
    command_line => "/usr/lib/nagios/plugins/check_tcp -H 127.0.0.1 -p ${title}"
  }
}
