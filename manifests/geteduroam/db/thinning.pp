# Thinning of geteduroam db
class sunet::geteduroam::db::thinning(
){
  file { '/usr/local/bin/geteduroam-db-thinning':
    ensure  => 'file',
    mode    => '0755',
    owner   => 'root',
    content => file('sunet/geteduroam/geteduroam-db-thinning.sh')
  }

  sunet::scriptherder::cronjob { 'db-thinning':
    cmd         => '/usr/local/bin/geteduroam-db-thinning',
    hour        => '4'
    minute      => '25',
    ok_criteria => ['exit_status=0', 'max_age=36h'],
  }
}
