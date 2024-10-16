# check_nagios
define sunet::nagios::nrpe_check_nagios ($display_name = undef) {
  sunet::nagios::nrpe_command {"check_process_${title}":
    command_line => '/usr/lib/nagios/plugins/check_nagios -e 2 -F /var/cache/nagios3/status.dat -C /usr/sbin/nagios3'
  }
}
