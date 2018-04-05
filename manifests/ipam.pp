class sunet::ipam {

  $bind9_allow_servers = hiera_array('bind9_allow_servers',[])
  $bind9_proto         = ['tcp', 'udp']
  $https_allow_servers = hiera_array('https_allow_servers',[])
  $db_password         = safe_hiera('nipap_db_password',[])
  $web_ui_username     = nipap-www
  $web_ui_password     = safe_hiera('web_UI_password',[])
  $welcome_message     = 'Welcome to SUNET IPAM. Please login using your SSO credentials.'
  $template_directory  = 'sunet/ipam'
  $domain              = $::domain
  $root_nipap_password = safe_hiera('root_nipap_password',[])
  $dns_nipap_password  = safe_hiera('dns_nipap_password',[])
  $primary_dns_server  = $::fqdn
  $name_servers        = ['ns1.sunet.se.', 'sunic.sunet.se.', 'server.nordu.net.']

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
  package { ['postgresql',
            'postgresql-9.5-ip4r',
            'postgresql-contrib',
            'apache2',
            'bind9',
            'libapache2-mod-wsgi',
            'libldap2-dev',
            'libsasl2-dev',
            'autopostgresqlbackup']:
    ensure => 'present',
  }
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
  -> file {'/root/nipapd.preseed':
      ensure  => file,
      mode    => '0644',
      content => template("${template_directory}/nipapd.preseed.erb"),
      }
  -> package {'nipapd':
      ensure       => present,
      responsefile => '/root/nipapd.preseed'
      }
  -> package {[nipap-cli, nipap-www]:
      ensure => present,
      }
  -> service {'nipapd':
      ensure => running,
      enable => true,
      }
  -> service {'apache2':
      ensure => running,
      enable => true,
      }

  file {'/root/change_db_password.sql':
    ensure  => file,
    mode    => '0644',
    content => template("${template_directory}/change_db_password.sql.erb"),
    require => Package['nipapd'],
  }
  -> exec {'change_db_password':
      user        => 'postgres',
      command     => 'psql -f /root/change_db_password.sql',
      subscribe   => File['/root/change_db_password.sql'],
      refreshonly => true,
      }
  -> exec {'create_web_ui_user':
      command => "nipap-passwd add --username ${web_ui_username} --password ${web_ui_password} --name 'User account for the web UI' --trusted",
      unless  => '/usr/sbin/nipap-passwd list | grep nipap-www',
      }
  -> exec {'create_root_local_user':
      command => "nipap-passwd add --username root --password ${root_nipap_password} --name 'local root user'",
      unless  => '/usr/sbin/nipap-passwd list | grep root',
      }
  -> exec {'create_dns_user':
      command => "nipap-passwd add --username dnsexporter --password ${dns_nipap_password} --name 'DNS user'",
      unless  => '/usr/sbin/nipap-passwd list | grep dnsexporter',
      }
  -> file {'/etc/nipap/nipap.conf':
      ensure  => file,
      mode    => '0644',
      content => template("${template_directory}/nipap.conf.erb"),
      notify  => Service['nipapd'],
      }
  -> file { '/root/.nipaprc':
      ensure  => file,
      owner   => 'root',
      group   => 'root',
      mode    => '0600',
      content => template("${template_directory}/.nipaprc.erb")
      }
  -> file { '/etc/bind/nipaprc':
      ensure  => file,
      owner   => 'root',
      group   => 'bind',
      mode    => '0644',
      content => template("${template_directory}/nipaprc_dns.erb")
      }
  -> file {'/etc/apache2/sites-available/nipap-default.conf':
      ensure  => file,
      mode    => '0644',
      content => template("${template_directory}/nipap-default.conf.erb"),
      notify  => Service['apache2'],
      }
  -> file {'/etc/apache2/sites-available/nipap-ssl.conf':
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
  -> file {'/usr/local/lib/python2.7/site-packages/pytter.py':
      ensure  => file,
      mode    => '0644',
      content => template("${template_directory}/pytter.py.erb"),
      }
  -> file {'/etc/nipap/nipap-www.ini':
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
  -> file_line { 'db_name':
      line   => 'DBNAMES="nipap postgres"',
      path   => '/etc/default/autopostgresqlbackup',
      ensure => 'present',
      match  => 'DBNAMES="all"',
     }
  -> file { '/etc/bind/generated':
      ensure  => directory,
      owner   => 'root',
      group   => 'bind',
      mode    => '2755',
      }
  -> vcsrepo { '/etc/bind/generated':
      ensure   => present,
      provider => git,
      }
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
      notify => Exec['reload_rndc'],
      }
  -> exec {'reload_rndc':
      command     => 'rndc reload',
      subscribe   => File['/etc/bind/named.conf.zones'],
      refreshonly => true,
      }
  -> file { '/usr/local/sbin/nipap2bind':
      ensure  => file,
      content => template("${template_directory}/nipap2bind.erb"),
      }
  -> file { '/etc/bind/generated/ipam.sh':
      ensure  => file,
      mode    => '0755',
      group   => 'bind',
      content => template("${template_directory}/ipam.sh.erb"),
      }
  -> sunet::scriptherder::cronjob { 'generate_reverse_zones':
      cmd           => '/etc/bind/generated/ipam.sh',
      minute        => '*/15',
      ok_criteria   => ['exit_status=0', 'max_age=35m'],
      warn_criteria => ['exit_status=0', 'max_age=1h'],
      }
}
