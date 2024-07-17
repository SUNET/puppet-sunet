class sunet::motd {
  file {'motd':
    ensure  => file,
    path    => '/etc/motd.tail',
    mode    => '0644',
    content => "

This machine (${facts['networking']['fqdn']}) is running ${facts['os']['name']} ${facts['os']['release']['major']}
using puppet version ${facts['puppetversion']} and cosmos

"
  }
}
