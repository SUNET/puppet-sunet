# This is the manifest that is used to build an IP address management server using Nipap.
# It also uses apache2 as the web service, bind9 for DNS configuration and autopostrgresql for backing up postgres database.

class sunet::ipam::main {

  # Installation of various packages that the host needs for the overall configuration.
  package { ['postgresql',
             'postgresql-9.5-ip4r',
             'postgresql-contrib',
             'libapache2-mod-wsgi',
             'libldap2-dev',
             'libsasl2-dev',
             'autopostgresqlbackup',
             'pwgen']:
    ensure => 'present',
  }
  -> class { 'python':
      version => 'system',
      pip     => true,
      dev     => true,
      }
  -> python::pip {'python-ldap': ensure => present, pkgname => 'python-ldap'}

  # Installaion of nipap follows.
  -> apt::source {'nipap':
      location      => 'http://spritelink.github.io/NIPAP/repos/apt',
      release       => 'stable',
      repos         => 'main extra',
      key           => {
      'id'     => '58E66DF09A12C9D752FD924C4481633C2094AABD',
      'source' => 'https://spritelink.github.io/NIPAP/nipap.gpg.key',
      },
      include       => {'deb' => true,},
      notify_update => true,
      }
  # The nipap installation is preseeded by below file.
  -> file { '/root/nipapd.preseed':
      ensure  => file,
      mode    => '0644',
      content => template('sunet/ipam//nipapd.preseed.erb'),
      }
  -> package { 'nipapd':
      ensure       => present,
      responsefile => '/root/nipapd.preseed'
      }

  # Installation of nipap-cli and nipap-www packages.
  -> package {[nipap-cli, nipap-www]:
      ensure => present,
      }
  -> service { 'nipapd':
      ensure => running,
      enable => true,
      }

  # Password for postgres database that nipap uses. The variable is used in change_db_password.sql.erb template.
  $db_password = safe_hiera('nipap_db_password',[])

  # Password of the web interface's user account to authenticate twoards the backend of nipap."
  # The variable is used in nipap.conf.erb template too.
  $web_ui_password = safe_hiera('web_UI_password',[])

  #The message users will see on the login screen of the web GUI. The variable is used in nipap.conf.erb template.
  $welcome_message = 'Welcome to SUNET IPAM. Please login using your SSO credentials.'

  # Autoconfiguration during the nipap installation creates a password for postgres database. This is later changed through
  # the following two resources so that the new password can be written into nipap.conf.erb template by puppet.
  file { '/root/change_db_password.sql':
    ensure  => file,
    mode    => '0644',
    content => template('sunet/ipam//change_db_password.sql.erb'),
    require => Package['nipapd'],
  }
  -> exec { 'change_db_password':
      user        => 'postgres',
      command     => 'psql -f /root/change_db_password.sql',
      subscribe   => File['/root/change_db_password.sql'],
      refreshonly => true,
      }
  # The web interface needs its own user account to authenticate towards the backend and it should be a trusted account.
  -> exec { 'create_web_ui_user':
      command => "nipap-passwd add --username nipap-www --password ${web_ui_password} --name 'User account for the web UI' --trusted",
      unless  => '/usr/sbin/nipap-passwd list | grep nipap-www',
      }
  # Nipap configuration file is created with above information.
  -> file { '/etc/nipap/nipap.conf':
      ensure  => file,
      mode    => '0644',
      content => template('sunet/ipam//nipap.conf.erb'),
      notify  => Service['nipapd'],
      }

  # The following is used by configuration file of service - autopostgresqlbackup that backs up the postgres databases.
  -> file_line { 'db_name':
      ensure => 'present',
      line   => 'DBNAMES="nipap postgres"',
      path   => '/etc/default/autopostgresqlbackup',
      match  => 'DBNAMES="all"',
      }
}
