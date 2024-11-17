# kopia
class sunet::packages::kopia {
    apt::key { 'kopia':
      id     => '7FB99DFD47809F0D5339D7D92273699AFD56A556',
      source => 'https://kopia.io/signing-key'
    }
    -> apt::source {'kopia':
      location => 'http://packages.kopia.io/apt/',
      release  => 'stable',
      repos    => 'main',
      key      => {'id' => 'FB99DFD47809F0D5339D7D92273699AFD56A556'},
      require  => Apt::Key['kopia'],
    }
    -> package { 'kopia':
      ensure   => 'latest',
      provider => 'apt',
      require  => Apt::Source['kopia'],
    }
}
