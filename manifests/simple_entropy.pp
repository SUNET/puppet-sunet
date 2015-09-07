class sunet::simple_entropy {
   package {'haveged': ensure => latest } ->
   service {'haveged': ensure => running }
   sunet::pollinate { 'https://random.nordu.net/': }
   service {"rng-tools":
      ensure    => stopped,
      pattern   => "/usr/sbin/rngd",
      hasstatus => false,
   }
}
