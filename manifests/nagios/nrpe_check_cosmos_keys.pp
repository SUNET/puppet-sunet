# Check gpg keys used by cosmos
define sunet::nagios::nrpe_check_cosmos_keys (
) {

  include sunet::nagios::nrpe_check_gpg_keys_bin

  sunet::nagios::nrpe_command { 'check_cosmos_keys':
    command_line => '/usr/lib/nagios/plugins/check_gpg_keys /etc/cosmos/keys',
  }
}
