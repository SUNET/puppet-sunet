# kopia
class sunet::packages::kopia {
    apt::keyring { 'kopia':
      ensure   => 'present',
      source   => 'https://kopia.io/signing-key',
      filename => 'kopia.io.asc',
    }
    -> apt::source {'kopia':
      location => 'http://packages.kopia.io/apt/',
      release  => 'stable',
      repos    => 'main',
      key      => {'id' => '2273699afd56a556', 'source' => 'kopia.io.asc'},
      require  => Apt::Key['kopia'],
    }
    -> package { 'kopia':
      ensure   => 'latest',
      provider => 'apt',
      require  => Apt::Source['kopia'],
    }
}
