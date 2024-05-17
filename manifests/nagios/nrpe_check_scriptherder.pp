# Check Scriptherder
define sunet::nagios::nrpe_check_scriptherder (
) {
    $scriptherder_from_cosmos = $sunet::server::install_scriptherder

    # Scriptherder bundled with puppet requires sudo and provides it's own NRPE configuration
    if $scriptherder_from_cosmos != true {
      sunet::nagios::nrpe_command { 'check_scriptherder':
        command_line => '/usr/local/bin/scriptherder --mode check',
      }
    }
}
