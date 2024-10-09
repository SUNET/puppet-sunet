# check_fileage
define sunet::nagios::nrpe_check_fileage (
  $filename     = undef,
  $warning_age  = undef,
  $critical_age = undef) {

  $_filename = $filename ? {
      undef   => $name,
      default => $filename
  }

  sunet::nagios::nrpe_command {"check_fileage_${title}":
    command_line => "/usr/lib/nagios/plugins/check_file_age -f ${_filename} -w ${warning_age} -c ${critical_age}"
  }
}
