# This manifest does the configuration of bind9 and generation of DNS zone records.
class sunet::ipam::dns_config {

  require sunet::ipam::main

  # The array of IP addresses who can talk to the host throug bind9.
  $bind9_allow_servers = hiera_array('bind9_allow_servers',[])

  # The protocols that bind9 will use to talk to allowed IPs.
  $bind9_proto = ['tcp', 'udp']

  sunet::misc::ufw_allow { 'allow_bind9':
    from  => $bind9_allow_servers,
    port  => '53',
    proto => $bind9_proto,
  }
  package { 'bind9':
    ensure => installed,
  }
  -> service { 'bind9':
      ensure => running,
      enable => true,
      }

  # Password of the bind9's user account to authenticate twoards the backend of nipap.
  # The variable is used in nipap.conf.erb template too.
  $dns_nipap_password = safe_hiera('dns_nipap_password',[])

  # Array of zones that the host is master to.
  $zones = hiera_array('zones',[])

  # Hostnames of the name servers in zone records. The variable is used in nipap2bind.erb template.
  $name_servers = ['ns1.sunet.se.', 'sunic.sunet.se.', 'server.nordu.net.']

  # Below directory holds all the zone records.
  file { '/etc/bind/generated':
    ensure  => directory,
    owner   => 'root',
    group   => 'bind',
    mode    => '2755',
    require => Package['bind9'],
  }
  # The directory is managed by git.
  -> vcsrepo { '/etc/bind/generated':
      ensure   => present,
      provider => git,
      }
  # Below file contains all the zones that the host is master to.
  -> file { '/etc/bind/named.conf.zones':
      ensure  => file,
      content => template('sunet/ipam/named.conf.zones.erb'),
      }
  -> file_line { 'include_named.conf.zones':
      ensure => 'present',
      line   => 'include "/etc/bind/named.conf.zones";',
      path   => '/etc/bind/named.conf',
      notify => Exec['reload_rndc'],
      }
  -> file { '/etc/bind/named.conf.options':
      ensure  => file,
      content => template('sunet/ipam/named.conf.options.erb'),
      notify  => Exec['reload_rndc'],
      }
  -> exec { 'reload_rndc':
      command     => 'rndc reload',
      unless      => 'named-checkconf /etc/bind/named.conf.zones && named-checkconf /etc/bind/named.conf && named-checkconf /etc/bind/named.conf.options',
      subscribe   => File['/etc/bind/named.conf.zones'],
      refreshonly => true,
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
      content => template('sunet/ipam/nipaprc_dns.erb')
      }
  # Below python file generate reverse DNS zones.
  -> file { '/usr/local/lib/python2.7/site-packages/pytter.py':
      ensure  => file,
      mode    => '0644',
      content => template('sunet/ipam/pytter.py.erb'),
      }
  # Below script updates the zone files that reside in `/etc/bind/generated'.
  -> file { '/usr/local/sbin/nipap2bind':
      ensure  => file,
      content => template('sunet/ipam/nipap2bind.erb'),
      }
  # Below script generates the reverse zones, reload zone database and commit the changes in `/etc/bind/generated'.
  -> file { '/etc/bind/generated/ipam.sh':
      ensure  => file,
      mode    => '0755',
      group   => 'bind',
      content => template('sunet/ipam/ipam.sh.erb'),
      }
  # Runtime of ipam.sh is managed by cron.
  -> sunet::scriptherder::cronjob { 'generate_reverse_zones':
      cmd           => '/etc/bind/generated/ipam.sh',
      minute        => '*/15',
      ok_criteria   => ['exit_status=0', 'max_age=35m'],
      warn_criteria => ['exit_status=0', 'max_age=1h'],
      }
}
