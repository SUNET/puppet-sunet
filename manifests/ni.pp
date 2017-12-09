class sunet::ni(

  String $ssl_cert,
  String $ssl_key,
  $test_server = false,
  $backup_server = false,
){
  require sunet::ni_packages

  $neo4j_pwd = safe_hiera('ni_neo4j_password',[])
  $ni_database_pwd = safe_hiera ('ni_database_password',[])
  $noclook_secret_key = safe_hiera ('noclook_secret_key',[])
  $google_api_key = safe_hiera ('google_api_key',[])
  $domain = $::domain
  $hostname = $::hostname

  service { 'neo4j':
    ensure => running,
    enable => true,
  }
  service { 'uwsgi':
    ensure => running,
    enable => true,
  }
  service { 'nginx':
    ensure => running,
    enable => true,
  }
  file { '/etc/neo4j/neo4j.conf':
    ensure  => file,
    mode    => '0644',
    content => template('sunet/ni/neo4j.conf.erb'),
    notify  => Service['neo4j'],
  }
  -> exec {'change_neo4j_pwd':
      command => "neo4j-admin set-initial-password ${neo4j_pwd}",
      creates => '/var/lib/neo4j/data/dbms/auth.ini',
      notify  => Service['neo4j'],
      }
  -> user {'ni':
      ensure   => present,
      password => '*',
      home     => '/var/opt/norduni',
      }
  -> file { '/var/opt/norduni':
      ensure => directory,
      owner  => 'ni',
      group  => 'ni',
      }
  -> file {'/var/opt/norduni/setupdb.sql':
      ensure  => file,
      mode    => '0644',
      content => template('sunet/ni/setupdb.sql.erb'),
      }
  exec {'postgres_setupdb':
      user        => 'postgres',
      command     => 'psql -f /var/opt/norduni/setupdb.sql',
      subscribe   => File['/var/opt/norduni/setupdb.sql'],
      refreshonly => true,
      }
  vcsrepo {'/var/opt/norduni/norduni':
      ensure   => present,
      provider => git,
      owner    => ni,
      group    => ni,
      source   => 'git://git.nordu.net/norduni.git',
      require  => User['ni'],
      }
  -> python::virtualenv {'/var/opt/norduni/norduni_environment':
      ensure       => present,
      requirements => '/var/opt/norduni/norduni/requirements/prod.txt',
      owner        => 'ni',
      group        =>'ni',
      cwd          => '/var/opt/norduni/norduni_environment',
      }
  -> file { '/var/opt/norduni/norduni/src/niweb/.env':
      ensure  => present,
      mode    => '0664',
      owner   => 'ni',
      group   => 'ni',
      content => template('sunet/ni/.env.erb'),
      notify  => Service['uwsgi'],
      }
  -> file {'/var/opt/norduni/python_commands':
      ensure  => file,
      mode    => '0755',
      content => template('sunet/ni/python_commands.erb'),
      }
  -> exec {'python_commands':
      command     => '/var/opt/norduni/python_commands',
      subscribe   => File['/var/opt/norduni/python_commands'],
      refreshonly => true,
      }
  -> file { '/etc/uwsgi/apps-available/noclook.ini':
      ensure  => present,
      mode    => '0644',
      content => template('sunet/ni/noclook.ini.erb'),
      notify  => Service['uwsgi'],
      }
  -> file { '/etc/uwsgi/apps-enabled/noclook.ini':
      ensure => link,
      target => '/etc/uwsgi/apps-available/noclook.ini',
      }
  -> file { '/tmp/django_cache':
      ensure  => directory,
      owner   => 'ni',
      group   => 'www-data',
      mode    => '0775',
      recurse => true,
      }
  -> file { '/var/opt/norduni/norduni/src/niweb/logs/':
      ensure  => directory,
      owner   => 'ni',
      group   => 'www-data',
      mode    => '0775',
      recurse => true,
      }
  -> exec { 'create_dhparam_pem':
      command => 'openssl dhparam -out /etc/ssl/dhparams.pem 2048',
      unless  => '/usr/bin/test -s /etc/ssl/dhparams.pem',
      }
  -> file { '/etc/nginx/sites-available/default':
      ensure  => file,
      mode    => '0644',
      content => template('sunet/ni/default.erb'),
      notify  => Service['nginx'],
      }
  -> vcsrepo {'/var/opt/norduni/sunet-nistore':
      ensure   => latest,
      provider => git,
      owner    => ni,
      group    => ni,
      source   => 'git://git.nordu.net/sunet-nistore.git',
      }
  -> file {'/var/opt/norduni/norduni/src/scripts/restore.conf/':
      ensure  => file,
      mode    => '0644',
      owner   => 'ni',
      group   => 'ni',
      content => template('sunet/ni/restore.conf.erb'),
      }

  if $test_server {
    file {'/var/opt/norduni/consume.sh/':
      ensure  => file,
      mode    => '0755',
      content => template('sunet/ni/consume.sh.erb'),
      require => User['ni'],
      }
    -> file {'/var/opt/norduni/norduni/src/scripts/sunet.conf':
        ensure  => file,
        mode    => '0644',
        owner   => 'ni',
        group   => 'ni',
        content => template('sunet/ni/sunet.conf.erb'),
        }
    -> sunet::scriptherder::cronjob { 'run_clone_script':
        cmd           => '/var/opt/norduni/norduni/src/scripts/clone.sh -r /var/opt/norduni/sunet-nistore/',
        user          => 'ni',
        minute        => '30',
        hour          => '6',
        monthday      => '1',
        ok_criteria   => ['exit_status=0', 'max_age=721h'],
        warn_criteria => ['exit_status=0', 'max_age=723h'],
        }
    -> sunet::scriptherder::cronjob { 'run_consume_script':
        cmd           => '/var/opt/norduni/consume.sh',
        user          => 'ni',
        minute        => '30',
        hour          => '4',
        ok_criteria   => ['exit_status=0', 'max_age=25h'],
        warn_criteria => ['exit_status=0', 'max_age=49h'],
        }
  }

  if $backup_server {
    sunet::scriptherder::cronjob { 'run_clone_script_ni2':
      cmd           => '/var/opt/norduni/norduni/src/scripts/clone.sh -r /var/opt/norduni/sunet-nistore/',
      user          => 'ni',
      minute        => '30',
      hour          => '6',
      ok_criteria   => ['exit_status=0', 'max_age=25h'],
      warn_criteria => ['exit_status=0', 'max_age=49h'],
      require       => User['ni']
      }
  }
  }
