# Install and configure chrony service. Default setup is client-only using NTS
# time sources. If you want to act as NTP server see $allow_list.
# Using the netnod NTS servers by default keeps us in line with MSBFS 2020:7
# with their time service being traceable to UTC(SP).
class sunet::chrony(
  Array[String] $ntp_servers = [],
  Array[String] $nts_servers = [
    'gbg1.nts.netnod.se',
    'gbg2.nts.netnod.se',
    'lul1.nts.netnod.se',
    'lul2.nts.netnod.se',
    'mmo1.nts.netnod.se',
    'mmo2.nts.netnod.se',
    'sth1.nts.netnod.se',
    'sth2.nts.netnod.se',
    'svl1.nts.netnod.se',
    'svl2.nts.netnod.se',
  ],
  Boolean $dhcp_time_sources = false,
  Integer $cmdport = 0,
  Array[String] $allow_list = [],
  Array[String] $ntsservercerts = [],
  Array[String] $ntsserverkeys = [],
) {
  package { 'chrony': ensure => 'installed' }

  service { 'chrony':
    ensure => running,
    enable => true,
  }

  file { '/etc/chrony/chrony.conf':
    ensure  => 'file',
    mode    => '0644',
    owner   => 'root',
    group   => 'root',
    content => template('sunet/chrony/chrony.conf.erb'),
    notify  => Service['chrony'],
  }

  exec { 'chronyc reload sources':
    refreshonly => true,
  }

  file { '/etc/chrony/sources.d/sunet.sources':
    ensure  => 'file',
    mode    => '0644',
    owner   => 'root',
    group   => 'root',
    content => template('sunet/chrony/sunet.sources.erb'),
    notify  => Exec['chronyc reload sources'],
  }
}
