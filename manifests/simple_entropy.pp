class sunet::simple_entropy {
   include haveged
   sunet::pollinate { 'https://random.nordu.net/': }
   service {"rng-tools":
      ensure    => stopped,
      pattern   => "/usr/sbin/rngd",
      hasstatus => false,
   }
}
