class sunet::ni_package {
  
  include apt

  apt::ppa {'ppa:webupd8team/java':}
  
  exec { 'accept_oracle_licence':
    command => "/bin/echo debconf shared/accepted-oracle-license-v1-1 select true | /usr/bin/debconf-set-selections",
  }
  
  apt::key {'neo4j_gpg_key1':
    id => '66D34E951A8C53D90242132B26C95CF201182252',
    source => 'https://debian.neo4j.org/neotechnology.gpg.key',
    }
  
  apt::key {'neo4j_gpg_key2':
    id => '1EEFB8767D4924B86EAD08A459D700E4D37F5F19',
    source => 'https://debian.neo4j.org/neotechnology.gpg.key',
    }
  
  apt::source {'neo4j':
    location => 'http://debian.neo4j.org/repo',
    release => 'stable/',
    repos => '',
    include  => {
    'deb' => true,
  },
    notify_update => true,
  }
 
  ensure_packages({
    'oracle-java8-installer' => { ensure => latest},
    'neo4j' => { ensure => '3.2.2'},
    'postgresql' => { ensure => latest},
    'git' => { ensure => latest},
    'libpq-dev' => { ensure => latest},
    'nginx-full' => { ensure => latest},
    'uwsgi' => {ensure => latest},
    'uwsgi-plugin-python' => {ensure => latest},
    },
    {'ensure' => 'present'}
  )

  apt::pin { 'neo4j':
    packages => 'neo4j',
    version => '3.2.2',
    priority => '600',
  }

  class { 'python':
    version    => 'system',
    dev        => true,
    virtualenv => true,
    pip => true,
  }

}

