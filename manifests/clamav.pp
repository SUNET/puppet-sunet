# A class to install and manage ClamAV anti-virus software.
class sunet::clamav (
  String $minute = '45',
  String $hour   = '*/2',
) {
  include sunet::packages::clamav
  include sunet::packages::clamav_daemon

  file { '/opt/clamav/':
    ensure  => directory,
    owner   => 'root',
    group   => 'root',
    mode    => '0755',
  }
  -> file { '/opt/clamav/scan.sh':
    ensure  => file,
    owner   => 'root',
    group   => 'root',
    mode    => '0744',
    content => template('sunet/clamav/scan.erb.sh'),
  }
  sunet::scriptherder::cronjob { 'clamav_scan':
    cmd           => '/opt/clamav/scan.sh',
    minute        => $minute,
    hour          => $hour,
    ok_criteria   => ['exit_status=0', 'max_age=3h'],
    warn_criteria => ['exit_status=0', 'max_age=5h'],
  }
}
