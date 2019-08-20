class sunet::ni{

  require sunet::ni_packages

  $neo4j_pwd = safe_hiera('ni_neo4j_password',[])
  $ni_database_pwd = safe_hiera ('ni_database_password',[])
  $noclook_secret_key = safe_hiera ('noclook_secret_key',[])
  $google_api_key = safe_hiera ('google_api_key',[])

  $ni_home ="/var/opt/norduni"
  $norduni_path =  "${ni_home}/norduni"
  $script_path = "${ni_home}/scripts"

  service {['neo4j', 'uwsgi', 'nginx']:
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
  -> file { '/etc/security/limits.conf':
      ensure => present,
      content => template('sunet/ni/limits.conf.erb'),
     }
  -> user {'ni':
      ensure   => present,
      password => '*',
      home     => "${ni_home}",
      shell    => '/bin/bash',
      }
  -> file { "${ni_home}":
      ensure => directory,
      owner  => 'ni',
      group  => 'ni',
      }
  -> file {"${ni_home}/setupdb.sql":
      ensure  => file,
      mode    => '0644',
      content => template('sunet/ni/setupdb.sql.erb'),
      }
  exec {'postgres_setupdb':
      user        => 'postgres',
      command     => 'psql -f /var/opt/norduni/setupdb.sql',
      subscribe   => File["${ni_home}/setupdb.sql"],
      refreshonly => true,
      }
  vcsrepo {"${norduni_path}":
      ensure   => present,
      provider => git,
      owner    => ni,
      group    => ni,
      source   => 'https://github.com/NORDUnet/ni.git',
      require  => User['ni'],
      }
  -> file { "${script_path}":
      ensure => directory,
      }
  -> file { "${script_path}/virtenv.sh":
      ensure  => present,
      content => template('sunet/ni/virtenv.sh.erb'),
      owner   => 'ni',
      group   => 'ni',
      mode    => '0744',
      }
 -> exec {'setup_virtenv':
      command => '/var/opt/norduni/scripts/virtenv.sh',
      creates => "${ni_home}/norduni_environment",
      user    => 'ni',
      group   => 'ni',
      notify  => Service['uwsgi'],
      }

  if $production_server {
    file { "${norduni_path}/src/niweb/.env":
      ensure  => present,
      mode    => '0664',
      owner   => 'ni',
      group   => 'ni',
      content => template('sunet/ni/.env-prod.erb'),
      require  => User['ni'],
      notify  => Service['uwsgi'],
    }
    file { "${ni_home}/.ssh":
      ensure  => directory,
      owner   => 'ni',
      group   => 'ni',
      recurse => true,
      require   => [ User['ni'], File["${ni_home}"] ],
    }
    -> sunet::snippets::secret_file { "${ni_home}/.ssh/ni_git_key":
        hiera_key   => 'ni_git_key',
        owner       => 'ni',
        group       => 'ni',
        }
    ->  sunet::snippets::ssh_pubkey_from_privkey { "${ni_home}/.ssh/ni_git_key": }

    -> file { "${ni_home}/.ssh/config":
        ensure => present,
        mode    => '0664',
        owner   => 'ni',
        group   => 'ni',
        content => template('sunet/ni/config.erb'),
    }
    -> vcsrepo {"${ni_home}/sunet-nistore":
        ensure   => present,
        provider => git,
        owner    => ni,
        group    => ni,
        user     => 'ni',
        source   => 'git@code.nordu.net:sunet-nistore.git',
        }
  }
  else {
    file { "${norduni_path}/src/niweb/.env":
      ensure  => present,
      mode    => '0664',
      owner   => 'ni',
      group   => 'ni',
      content => template('sunet/ni/.env-others.erb'),
      require => User['ni'],
      notify  => Service['uwsgi'],
    }
    vcsrepo {"${ni_home}/sunet-nistore":
      ensure   => present,
      provider => git,
      owner    => ni,
      group    => ni,
      source   => 'git://code.nordu.net/sunet-nistore.git',
      }
  }
  -> file {"${script_path}/python_commands":
      ensure  => file,
      mode    => '0755',
      content => template('sunet/ni/python_commands.erb'),
      }
  -> exec {'python_commands':
      command     => '/var/opt/norduni/scripts/python_commands',
      subscribe   => File["${script_path}/python_commands"],
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
  -> file { "${norduni_path}/src/niweb/logs/":
      ensure  => directory,
      owner   => 'ni',
      group   => 'www-data',
      mode    => '0775',
      recurse => true,
      }
  -> file { '/etc/nginx/sites-available/default':
      ensure  => file,
      mode    => '0644',
      content => template('sunet/ni/default.erb'),
      notify  => Service['nginx'],
      }
  -> file {"${norduni_path}/src/scripts/restore.conf/":
      ensure  => file,
      mode    => '0644',
      owner   => 'ni',
      group   => 'ni',
      content => template('sunet/ni/restore.conf.erb'),
      }

  if $test_server {
    sunet::scriptherder::cronjob { 'run_clone_script':
      cmd           => '/var/opt/norduni/norduni/src/scripts/clone-gitonly.sh -r /var/opt/norduni/sunet-nistore/',
      user          => 'ni',
      minute        => '30',
      hour          => '6',
      monthday      => '1',
      ok_criteria   => ['exit_status=0', 'max_age=721h'],
      warn_criteria => ['exit_status=0', 'max_age=723h'],
      }
  }

  if $backup_server {
    sunet::scriptherder::cronjob { 'run_clone_script_ni2':
      cmd           => '/var/opt/norduni/norduni/src/scripts/clone-gitonly.sh -r /var/opt/norduni/sunet-nistore/',
      user          => 'ni',
      minute        => '30',
      hour          => '6',
      ok_criteria   => ['exit_status=0', 'max_age=25h'],
      warn_criteria => ['exit_status=0', 'max_age=49h'],
      require       => User['ni']
    }
  }

  if $production_server {
    file {"${norduni_path}/src/niweb/apps/saml2auth/config.py":
      ensure  => file,
      mode    => '0644',
      owner   => 'ni',
      group   => 'ni',
      content => template('sunet/ni/config.py.erb'),
    }
    -> vcsrepo {"${ni_home}/nerds":
      ensure   => present,
      provider => git,
      owner    => ni,
      group    => ni,
      source   => 'https://github.com/fredrikt/nerds.git',
      }
    -> vcsrepo {"${ni_home}/nunoc-ops":
      ensure   => present,
      provider => git,
      owner    => ni,
      group    => ni,
      source   => 'git://gitops.sunet.se/nunoc-ops.git',
      }

    $scripts = ['backup.sh', 'produce-parallel.sh', 'git-gc.sh']

    $scripts.each |$script|{
      file { "${script_path}/${script}":
        ensure  => present,
        content => template("sunet/ni/${script}.erb"),
        owner   => 'ni',
        group   => 'ni',
        mode    => '0744',
        require => User['ni'],
      }
    }
    file { '/usr/local/bin/ni-pull.sh':
      ensure  => file,
      content => template("sunet/ni/ni-pull.sh.erb"),
      owner   => 'ni',
      group   => 'ni',
      mode    => '0744',
      require => User['ni'],
    }
    -> sunet::scriptherder::cronjob { 'run_backup_script':
        cmd           => '/var/opt/norduni/scripts/backup.sh',
        user          => 'ni',
        minute        => '0',
        hour          => '2',
        ok_criteria   => ['exit_status=0', 'max_age=25h'],
        warn_criteria => ['exit_status=0', 'max_age=49h'],
        }
    -> sunet::scriptherder::cronjob { 'run_produce_script':
        cmd           => '/var/opt/norduni/temp_producer/produce.sh',
        user          => 'ni',
        minute        => '0',
        hour          => '3',
        ok_criteria   => ['exit_status=0', 'max_age=25h'],
        warn_criteria => ['exit_status=0', 'max_age=49h'],
    }
    -> sunet::scriptherder::cronjob { 'run_git_cleanup_script':
        cmd           => '/var/opt/norduni/scripts/git-gc.sh -s -r /var/opt/norduni/sunet-nistore',
        user          => 'ni',
        minute        => '30',
        hour          => '7',
        ok_criteria   => ['exit_status=0', 'max_age=25h'],
        warn_criteria => ['exit_status=0', 'max_age=49h'],
        }
    -> file { "${script_path}/md-update.sh":
        ensure  => file,
        mode    => '0755',
        content => template('sunet/ipam/md-update.sh.erb'),
        }
    -> sunet::scriptherder::cronjob { 'update_metadata':
         cmd    => '/var/opt/norduni/scripts/md-update.sh -c /var/opt/norduni/mds-swamid.crt -q -o /var/opt/norduni/norduni/src/niweb/apps/saml2auth/swamid-idp.xml https://mds.swamid.se/md/swamid-idp.xml',
         user   => 'ni',
         minute => '25',
        }
  }

  if ($production_server or $test_server) {
    file {"${norduni_path}/src/scripts/sunet.conf":
      ensure  => file,
      mode    => '0644',
      owner   => 'ni',
      group   => 'ni',
      content => template('sunet/ni/sunet.conf.erb'),
      require => User['ni'],
    }
    -> file {"${script_path}/consume.sh/":
        ensure  => file,
        mode    => '0755',
        owner   => 'ni',
        group   => 'ni',
        content => template('sunet/ni/consume.sh.erb'),
        }
    -> sunet::scriptherder::cronjob { 'run_consume_script':
        cmd           => '/var/opt/norduni/scripts/consume.sh',
        user          => 'ni',
        minute        => '30',
        hour          => '4',
        ok_criteria   => ['exit_status=0', 'max_age=25h'],
        warn_criteria => ['exit_status=0', 'max_age=49h'],
        }
  }
}