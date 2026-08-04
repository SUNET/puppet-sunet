class sunet::dehydrated::client_cleanup(
  String  $version,
  String $basedir = '/etc/dehydrated',
){

  $src_url = "https://raw.githubusercontent.com/dehydrated-io/dehydrated/refs/tags/${version}/dehydrated"

  sunet::remote_file { '/usr/sbin/dehydrated':
    remote_location => $src_url,
    mode            => '0755'
  }

  $gc_conf = "${basedir}/dehydrated-cleanup.conf"

  file { $gc_conf :
    owner   => 'root',
    mode    => '0640',
    content => "BASEDIR=${basedir}\nWELLKNOWN=/var/tmp\n",
  }

  sunet::scriptherder::cronjob { 'dehydrated_cleanup':
    cmd           => "sh -c 'test -x /usr/sbin/dehydrated && /usr/sbin/dehydrated --cleanup --config ${gc_conf}'",
    special       => 'daily',
    ok_criteria   => ['exit_status=0', 'max_age=50h'],
    warn_criteria => ['exit_status=0', 'max_age=72h'],
  }
}