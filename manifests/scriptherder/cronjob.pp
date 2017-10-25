# Run a cronjob and create a scriptherder monitoring file
define sunet::scriptherder::cronjob(
  # cron parameters
  String $cmd,
  Enum['present', 'absent'] $ensure        = 'present',
  String                    $user          = 'root',
  Optional[String]          $hour          = undef,
  Optional[String]          $minute        = undef,
  Optional[String]          $monthday      = undef,
  Optional[String]          $weekday       = undef,
  Optional[String]          $special       = undef,    # e.g. 'daily'
  # scriptherder parameters
  Array                     $ok_criteria   = ['exit_status=0'],
  Array                     $warn_criteria = [],
  Boolean                   $purge_results = false,    # set to 'true' to remove job metadata files
) {
  # used in template scriptherder_check.ini.erb
  $scriptherder_ok = join($ok_criteria, ', ')
  $scriptherder_warn = join($warn_criteria, ', ')

  $_file_ensure = $ensure ? {
    'present' => 'file',
    'absent'  => 'absent',
  }

  file { "/etc/scriptherder/check/${name}.ini" :
    ensure  => $_file_ensure,
    mode    => '644', # to allow NRPE to read it
    group   => 'root',
    content => template('sunet/scriptherder/scriptherder_check.ini.erb'),
  } ->

  cron { $name:
    command  => "/usr/local/bin/scriptherder --mode wrap --syslog --name ${name} -- ${cmd}",
    ensure   => $ensure,
    user     => $user,
    hour     => $hour,
    minute   => $minute,
    monthday => $monthday,
    weekday  => $weekday,
    special  => $special,
  }

  if $ensure == 'absent' and $purge_results {
    exec { "scriptherder_purge_results_${name}":
      command => "/bin/rm -f '/var/cache/scriptherder/${name}_'*",
    }
  }
}
