class sunet::ni_packages{

  apt::key {'neo4j_gpg_key1':
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
  -> package { ['openjdk-8-jre',
                'python3-pip',
                'postgresql',
                'git',
                'libpq-dev',
                'nginx-full',
                'uwsgi',
                'uwsgi-plugin-python3']:
      ensure => latest,
      }
  #-> exec {'install_virtualenv':
  #    command     => 'pip3 install -U pip && pip3 install virtualenv',
  #    }
  -> package {'neo4j':
      ensure => present,
      }
  -> apt::pin { 'neo4j':
      packages => 'neo4j',
      version  => '>=3.2.2 < 4.0.0',
      priority => '600',
      }
  if $production_server {
    package { ['libffi-dev',
               'xmlsec1']:
      ensure => latest,
      }
  }
}
