# Run a cronjob and create a scriptherder monitoring file
define sunet::scriptherder::cronjob(
  # cron parameters
  String $cmd,
  Optional[String]          $job_name      = undef,
  Enum['present', 'absent'] $ensure        = 'present',
  String                    $user          = 'root',
  Optional[Array[String]]   $environment   = undef,
  Optional[String]          $hour          = undef,
  Optional[String]          $minute        = undef,
  Optional[String]          $monthday      = undef,
  Optional[String]          $weekday       = undef,
  Optional[String]          $special       = undef,    # e.g. 'daily'
  # scriptherder parameters
  Array[String[1]]          $ok_criteria   = ['exit_status=0'],
  Array[String[1]]          $warn_criteria = ['exit_status=0'],
  Boolean                   $purge_results = false,    # set to 'true' to remove job metadata files
) {
  $safe_name = regsubst(pick($job_name, $title), '[^0-9A-Za-z._\-]', '_', 'G')

  # used in template scriptherder_check.ini.erb
  $scriptherder_ok = join($ok_criteria, ', ')
  $scriptherder_warn = join($warn_criteria, ', ')

  $_file_ensure = $ensure ? {
    'present' => 'file',
    'absent'  => 'absent',
  }

  file { "/etc/scriptherder/check/${safe_name}.ini" :
    ensure  => $_file_ensure,
    mode    => '0644', # to allow NRPE to read it
    group   => 'root',
    content => template('sunet/scriptherder/scriptherder_check.ini.erb'),
  }

  if $special == 'daily' and lookup(scriptherder_daily_hour, undef, undef, undef) =~ Integer {
    $_special = 'absent'
    $_hour    = lookup('scriptherder_daily_hour', undef, undef, undef)
    $_minute  = fqdn_rand(60, $safe_name)
  } else {
    $_special = $special
    $_hour    = $hour
    $_minute  = $minute
  }

  cron { $safe_name:
    ensure      => $ensure,
    command     => "/usr/local/bin/scriptherder --mode wrap --syslog --name ${safe_name} -- ${cmd}",
    environment => $environment,
    user        => $user,
    hour        => $_hour,
    minute      => $_minute,
    monthday    => $monthday,
    weekday     => $weekday,
    special     => $_special,
  }

  if $ensure == 'absent' and $purge_results {
    exec { "scriptherder_purge_results_${safe_name}":
      command => "/bin/rm -f '/var/cache/scriptherder/${safe_name}_'*",
    }
  }
}
