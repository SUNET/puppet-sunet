class sunet::simple_entropy {
   package {'haveged': ensure => latest } ->
   service {'haveged': ensure => running }
   sunet::pollinate { 'https://random.nordu.net/': }
}
