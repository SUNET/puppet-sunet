# Check available updates using the host's package manager.
define sunet::nagios::nrpe_check_package_updates () {
  include sunet::nagios::package_updates
}
