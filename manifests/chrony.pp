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

  $distro = $facts['os']['distro']['id']
  $release = $facts['os']['distro']['release']['major']

  if $distro == 'Ubuntu' or ($distro == 'Debian' and versioncmp($release, '12') <= 0) {
    $use_leapseclist = false
  } else {
    $use_leapseclist = true
  }

  ### BEGIN sunet::ntp cleanup
  # Cleanup potential remains from previous usage of sunet::ntp
  if $facts['os']['name'] == 'AlmaLinux' {
    $service = 'chronyd'
    $config = '/etc/chrony.conf'
    $sources = '/etc/chrony.d'
    $keyfile = '/etc/chrony.keys'
    $driftfile = '/var/lib/chrony/drift'
  } else {
    $service = 'chrony'
    $config = '/etc/chrony/chrony.conf'
    $sources = '/etc/chrony/sources.d'
    $keyfile = '/etc/chrony/chrony.keys'
    $driftfile = '/var/lib/chrony/chrony.drift'
    package { 'ntp': ensure => 'purged' }
    package { 'ntpsec': ensure => 'purged' }
  }

  # Some files that are left behind even after purge because they are created
  # manually by sunet::ntp on Ubuntu.
  if $facts['os']['distro']['id'] == 'Ubuntu' {
    include sunet::systemd_reload

    file { '/etc/systemd/system/multi-user.target.wants/ntp.service':
      ensure => 'absent',
      notify => [Class['sunet::systemd_reload']]
    }
    file { '/etc/systemd/system/ntp.service':
      ensure => 'absent',
      notify => [Class['sunet::systemd_reload']]
    }
  }
  ### END sunet::ntp cleanup

  package { 'chrony': ensure => 'installed' }

  service { $service:
    ensure  => running,
    enable  => true,
    require => Package['chrony'],
  }

  file { $config:
    require => Package['chrony'],
    ensure  => 'file',
    mode    => '0644',
    owner   => 'root',
    group   => 'root',
    content => template('sunet/chrony/chrony.conf.erb'),
    notify  => Service[$service],
  }

  exec { 'chronyc reload sources':
    require     => Service[$service],
    refreshonly => true,
  }

  file { $sources:
    ensure  => directory,
    require => Package['chrony'],
  }
  file { "${sources}/sunet.sources":
    ensure  => 'file',
    mode    => '0644',
    owner   => 'root',
    group   => 'root',
    content => template('sunet/chrony/sunet.sources.erb'),
    notify  => Exec['chronyc reload sources'],
  }
}
