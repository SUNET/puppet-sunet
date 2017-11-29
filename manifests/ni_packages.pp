class sunet::ni_packages {

  apt::ppa {'ppa:webupd8team/java':}
  -> exec { 'accept_oracle_licence':
      command => '/bin/echo debconf shared/accepted-oracle-license-v1-1 select true | /usr/bin/debconf-set-selections',
      }
  -> apt::key {'neo4j_gpg_key1':
      id     => '66D34E951A8C53D90242132B26C95CF201182252',
      source => 'https://debian.neo4j.org/neotechnology.gpg.key',
      }
  -> apt::key {'neo4j_gpg_key2':
      id     => '1EEFB8767D4924B86EAD08A459D700E4D37F5F19',
      source => 'https://debian.neo4j.org/neotechnology.gpg.key',
      }
  -> apt::source {'neo4j':
      location      => 'http://debian.neo4j.org/repo',
      release       => 'stable/',
      repos         => '',
      include       => {
      'deb' => true,
      },
      notify_update => true,
      }
  -> package {'oracle-java8-installer':
      ensure => latest
      }
  -> package {'neo4j':
      ensure => '3.2.2',
      }
  -> package {'postgresql':
      ensure => latest
      }
  -> package {'git':
      ensure => latest
      }
  -> package {'libpq-dev':
      ensure => latest
      }
  -> package {'nginx-full':
      ensure => latest
      }
  -> package {'uwsgi':
      ensure => latest
      }
  -> package {'uwsgi-plugin-python':
      ensure => latest
      }
  -> apt::pin { 'neo4j':
      packages => 'neo4j',
      version  => '3.2.2',
      priority => '600',
      }

  class { 'python':
    version    => 'system',
    dev        => true,
    virtualenv => true,
    pip        => true,
  }
}
