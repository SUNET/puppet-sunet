class sunet::simple_entropy {
   package {'haveged': ensure => latest } ->
   service {'haveged': ensure => running } ->
   cron { 'every-second-hour-restart-haveged':
      command => 'service haveged restart',
      user    => 'root',
      hour    => '*/2',
      minute  => 10
   }
   sunet::pollinate { 'https://random.nordu.net/': }
}
