# kopia
class sunet::packages::kopia {
    apt::key { 'kopia':
      id     => '2273699afd56a556',
      source => 'https://kopia.io/signing-key'
    }
    -> apt::source {'kopia':
      location => 'http://packages.kopia.io/apt/',
      release  => 'stable',
      repos    => 'main',
      key      => {'id' => '2273699afd56a556'},
      require  => Apt::Key['kopia'],
    }
    -> package { 'kopia':
      ensure   => 'latest',
      provider => 'apt',
      require  => Apt::Source['kopia'],
    }
}
