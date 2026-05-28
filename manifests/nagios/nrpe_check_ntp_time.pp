# Check NTP
define sunet::nagios::nrpe_check_ntp_time (
  String $host = 'ntp.se',
) {
    sunet::nagios::nrpe_command { 'check_ntp_time':
      command_line => "/usr/lib/nagios/plugins/check_ntp_time -H ${host}",
    }
}
