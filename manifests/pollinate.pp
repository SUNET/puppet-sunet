define sunet::pollinate($device = '/dev/random') {
  if ($facts['os']['name'] == 'Ubuntu') {
    if ($facts['os']['release']['full'] == '12.04') {
      apt::ppa {'ppa:ndn/pollen': }
    } else {
      apt::ppa {'ppa:ndn/pollen': ensure => absent }
    }
    package {'pollinate': ensure => absent }
    file { '/etc/default/pollinate':
      ensure => file,
      owner  => root,
      group  => root,
      content => template('sunet/pollen/pollinate.erb')
    }
    cron { 'repollinate': ensure => absent,
    }
  }
}
