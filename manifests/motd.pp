class sunet::motd {
   file {'motd':
      ensure   => file,
      path     => '/etc/motd.tail',
      mode     => '0644',
      content  => "

This machine (${::fqdn}) is running ${::operatingsystem} ${::operatingsystemrelease} 
using puppet version ${::puppetversion} and cosmos

"
   }
}
