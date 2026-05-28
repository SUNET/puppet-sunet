# Check load
define sunet::nagios::nrpe_check_load (
  String $critical = '15,10,5',
  String $warning = '15,10,5',
) {

  $_loadw = lookup('check_load_warning', undef, undef, $warning)
  $_loadc = lookup('check_load_critical', undef, undef, $critical)

  sunet::nagios::nrpe_command {'check_load':
    command_line => "/usr/lib/nagios/plugins/check_load -w ${_loadw} -c ${_loadc}"
  }

}
