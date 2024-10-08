class sunet::simple_entropy {
  package {'haveged': ensure => latest }
  -> service {'haveged': ensure => running }
  -> cron { 'every-second-hour-restart-haveged':
      command => 'pkill -9 haveged ; sleep 2; pkill -9 haveged ; /usr/sbin/service haveged restart',
      user    => 'root',
      hour    => '*/2',
      minute  => 10
  }
  sunet::pollinate { 'https://random.sunet.se/': }
}
