# Adding cosmos information to motd
class sunet::motd {
  file { '/etc/motd.tail':
      ensure  => absent,
  }
  file {'/etc/update-motd.d/60-sunet':
    ensure  => file,
    mode    => '0755',
    content => "#!/bin/sh\necho \"\\nThis machine (${facts['networking']['fqdn']}) is running ${facts['os']['name']} ${facts['os']['release']['major']} using puppet version ${facts['puppetversion']} and cosmos\""
  }
}
