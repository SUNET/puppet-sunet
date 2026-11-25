# Check users
define sunet::nagios::nrpe_check_users (
  Integer $critical = 5,
  Integer $warning = 10,
) {
  include sunet::nagios::nrpe_paths

  $_w = lookup('check_users_warning', undef, undef, $warning)
  $_c = lookup('check_users_critical', undef, undef, $critical)

  sunet::nagios::nrpe_command {'check_users':
    command_line => "${sunet::nagios::nrpe_paths::plugins}/check_users -w ${_w} -c ${_c}"
  }
}
