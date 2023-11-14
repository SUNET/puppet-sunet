# Check Scriptherder
define sunet::nagios::nrpe_check_scriptherder (
) {
    sunet::nagios::nrpe_command { 'check_scriptherder':
      command_line => '/usr/local/bin/scriptherder --mode check',
    }
}
