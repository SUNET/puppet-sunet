# Adding cosmos information to motd
class sunet::motd {
  file {'motd':
    ensure  => file,
    path    => '/etc/update-motd.d/60-sunet',
    mode    => '0755',
    content => "echo \"This machine (${facts['networking']['fqdn']}) is running ${facts['os']['name']} ${facts['os']['release']['major']} using puppet version ${facts['puppetversion']} and cosmos\""
  }
}
