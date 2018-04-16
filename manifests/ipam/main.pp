# This is the manifest that is used to build an IP address management server using Nipap.
# It also uses apache2 as the web service, bind9 for DNS configuration and autopostrgresql for backing up postgres database.

class sunet::ipam {

  # Directory where the template lies to be used by this manifest.
  $template_directory  = 'sunet/ipam'

  # Domain name of the host the manifest is used by. The variable is used in nipap-default.conf.erb template.
  $domain              = $::domain

  # The hash containing local user information who can use nipap cli.
  $cli_users           = hiera_hash('ipam_cli_users')

  # The array of IP addresses who can talk to the host throug bind9.
  $bind9_allow_servers = hiera_array('bind9_allow_servers',[])

  # The protocols that bind9 will use to talk to allowed IPs.
  $bind9_proto         = ['tcp', 'udp']

  # The array of IP addresses that are allowed to communicate over https.
  $https_allow_servers = hiera_array('https_allow_servers',[])

  # Password for postgres database that nipap uses. The variable is used in change_db_password.sql.erb template.
  $db_password         = safe_hiera('nipap_db_password',[])

  # Password of the web interface's user account to authenticate twoards the backend of nipap.
  # The variable is used in nipap.conf.erb template too.
  $web_ui_password     = safe_hiera('web_UI_password',[])

  #The message users will see on the login screen of the web GUI. The variable is used in nipap.conf.erb template.
  $welcome_message     = 'Welcome to SUNET IPAM. Please login using your SSO credentials.'

  # Hostname of SOA in zone records. The variable is used in nipap2bind.erb template.
  $primary_dns_server  = $::fqdn

  # Hostnames of the name servers in zone records. The variable is used in nipap2bind.erb template.
  $name_servers        = ['ns1.sunet.se.', 'sunic.sunet.se.', 'server.nordu.net.']

  # Password of the bind9's user account to authenticate twoards the backend of nipap.
  # The variable is used in nipap.conf.erb template too.
  $dns_nipap_password  = safe_hiera('dns_nipap_password',[])


  # The following resources are used to add special ufw rules in the host.
  ufw::allow {'allow_http': ip => 'any', port => '80'}

  sunet::misc::ufw_allow { 'allow_https':
      from => $https_allow_servers,
      port => '443',
  }
  sunet::misc::ufw_allow { 'allow_bind9':
    from  => $bind9_allow_servers,
    port  => '53',
    proto => $bind9_proto,
  }

  # Installation of packages that the host needs for the overall configuration.
  package { ['postgresql',
            'postgresql-9.5-ip4r',
            'postgresql-contrib',
            'apache2',
            'bind9',
            'libapache2-mod-wsgi',
            'libldap2-dev',
            'libsasl2-dev',
            'autopostgresqlbackup',
            'pwgen']:
    ensure => 'present',
  }

  # Installaion of nipap follows.
  -> class { 'python':
      version => 'system',
      pip     => true,
      dev     => true,
      }
  -> python::pip {'python-ldap': ensure => present, pkgname => 'python-ldap'}
  -> apt::source {'nipap':
      location      => 'http://spritelink.github.io/NIPAP/repos/apt',
      release       => 'stable',
      repos         => 'main extra',
      key           => {
      'id'     => '58E66DF09A12C9D752FD924C4481633C2094AABD',
      'source' => 'https://spritelink.github.io/NIPAP/nipap.gpg.key',
      },
      include       => {
      'deb' => true,
      },
      notify_update => true,
      }
  -> file { '/root/nipapd.preseed': # The nipap installation is preseeded by this file.
      ensure  => file,
      mode    => '0644',
      content => template("${template_directory}/nipapd.preseed.erb"),
      }
  -> package { 'nipapd':
      ensure       => present,
      responsefile => '/root/nipapd.preseed'
      }

  # Installation of nipap-cli and nipap-www packages.
  -> package {[nipap-cli, nipap-www]:
      ensure => present,
      }

  # Making sure that certain services are running.
  -> service { 'nipapd':
      ensure => running,
      enable => true,
      }
  -> service { 'apache2':
      ensure => running,
      enable => true,
      }


  # Autoconfiguration during the nipap installation creates a password for postgres database. This is later changed through
  # the following two resources so that the new password can be written into nipap.conf.erb template.
  file { '/root/change_db_password.sql':
    ensure  => file,
    mode    => '0644',
    content => template("${template_directory}/change_db_password.sql.erb"),
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
      content => template("${template_directory}/nipap.conf.erb"),
      notify  => Service['nipapd'],
      }

  # Configuration of the web service follows.
  -> file { '/etc/apache2/sites-available/nipap-default.conf':
      ensure  => file,
      mode    => '0644',
      content => template("${template_directory}/nipap-default.conf.erb"),
      notify  => Service['apache2'],
      }
  -> file { '/etc/apache2/sites-available/nipap-ssl.conf':
      ensure  => file,
      mode    => '0644',
      content => template("${template_directory}/nipap-ssl.conf.erb"),
      }
  -> file { '/etc/apache2/sites-enabled/nipap-ssl.conf':
      ensure => link,
      target => '/etc/apache2/sites-available/nipap-ssl.conf',
      }
  -> file { '/etc/apache2/sites-enabled/nipap-default.conf':
      ensure => link,
      target => '/etc/apache2/sites-available/nipap-default.conf',
      }
  -> file { '/etc/nipap/nipap-www.ini':
      ensure  => file,
      mode    => '0644',
      content => template("${template_directory}/nipap-www.ini.erb"),
      }
  -> file { '/var/cache/nipap-www':
      ensure  => directory,
      owner   => 'www-data',
      group   => 'www-data',
      mode    => '0755',
      recurse => true,
      }

  # The following is used by configuration file of service - autopostgresqlbackup that backs up the postgres databases.
  -> file_line { 'db_name':
      ensure => 'present',
      line   => 'DBNAMES="nipap postgres"',
      path   => '/etc/default/autopostgresqlbackup',
      match  => 'DBNAMES="all"',
      }

  # Configuration of bind9 and generation of DNS zone records follows.

  # Below directory holds all the zone records.
  -> file { '/etc/bind/generated':
      ensure => directory,
      owner  => 'root',
      group  => 'bind',
      mode   => '2755',
      }
  # The directory is managed by git.
  -> vcsrepo { '/etc/bind/generated':
      ensure   => present,
      provider => git,
      }
  # Below file contains all the zones that the host is master to.
  -> file { '/etc/bind/named.conf.zones':
      ensure  => file,
      content => template("${template_directory}/named.conf.zones.erb"),
      }
  -> file_line { 'include_named.conf.zones':
      ensure => 'present',
      line   => 'include "/etc/bind/named.conf.zones";',
      path   => '/etc/bind/named.conf',
      notify => Exec['reload_rndc'],
      }
  -> file { '/etc/bind/named.conf.options':
      ensure  => file,
      content => template("${template_directory}/named.conf.options.erb"),
      notify  => Exec['reload_rndc'],
      }
  -> exec { 'reload_rndc':
      command     => 'rndc reload',
      subscribe   => File['/etc/bind/named.conf.zones'],
      refreshonly => true,
      }
  # Below python file generate reverse DNS zones.
  -> file { '/usr/local/lib/python2.7/site-packages/pytter.py':
      ensure  => file,
      mode    => '0644',
      content => template("${template_directory}/pytter.py.erb"),
      }
  # Below script updates the zone files that reside in `/etc/bind/generated'.
  -> file { '/usr/local/sbin/nipap2bind':
      ensure  => file,
      content => template("${template_directory}/nipap2bind.erb"),
      }
  # Below script generates the reverse zones, reload zone database and commit the changes in `/etc/bind/generated'.
  -> file { '/etc/bind/generated/ipam.sh':
      ensure  => file,
      mode    => '0755',
      group   => 'bind',
      content => template("${template_directory}/ipam.sh.erb"),
      }
  # Follwoing two resources create Bind9's user account to use the nipap cli.
  -> exec { 'create_dns_user':
      command => "nipap-passwd add --username dnsexporter --password ${dns_nipap_password} --name 'DNS user'",
      unless  => '/usr/sbin/nipap-passwd list | grep dnsexporter',
      }
  -> file { '/etc/bind/nipaprc':
      ensure  => file,
      owner   => 'root',
      group   => 'bind',
      mode    => '0644',
      content => template("${template_directory}/nipaprc_dns.erb")
      }
  # Runtime of ipam.sh is managed by cron.
  -> sunet::scriptherder::cronjob { 'generate_reverse_zones':
      cmd           => '/etc/bind/generated/ipam.sh',
      minute        => '*/15',
      ok_criteria   => ['exit_status=0', 'max_age=35m'],
      warn_criteria => ['exit_status=0', 'max_age=1h'],
      }

  # Local user account creation for nipap cli users.
  create_resources ('sunet::ipam::cli_user', $cli_users)
}
