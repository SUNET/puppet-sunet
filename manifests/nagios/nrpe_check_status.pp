# Check status
define sunet::nagios::nrpe_check_status (
) {
  sunet::nagios::nrpe_command {'check_status':
    command_line => '/usr/local/bin/check_status'
  }
}
