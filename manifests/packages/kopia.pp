# kopia
class sunet::packages::kopia {
    file {'/etc/cosmos/apt/keys/kopia-7FB99DFD47809F0D5339D7D92273699AFD56A556.pub':
        ensure  => file,
        mode    => '0644',
        content => template('sunet/packages/kopia-7FB99DFD47809F0D5339D7D92273699AFD56A556.pub.erb'),
    }
    -> apt::key { 'kopia':
      id     => '7FB99DFD47809F0D5339D7D92273699AFD56A556',
      source => '/etc/cosmos/apt/keys/kopia-7FB99DFD47809F0D5339D7D92273699AFD56A556.pub'
    }
    -> apt::source {'kopia':
      location => 'http://packages.kopia.io/apt/',
      release  => 'stable',
      repos    => 'main',
      key      => {'id' => '7FB99DFD47809F0D5339D7D92273699AFD56A556'},
      require  => Apt::Key['kopia'],
    }
    -> exec { 'kopia_apt_get_update':
      command => '/usr/bin/apt-get update',
      unless  => '/usr/bin/dpkg -l kopia',
    }
    -> package { 'kopia':
      ensure   => 'installed',
      provider => 'apt',
      require  => Apt::Source['kopia'],
    }
}
