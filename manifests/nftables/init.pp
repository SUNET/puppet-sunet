# Setup nftables on a host
class sunet::nftables::init(
  Boolean $default_log = true,
  Boolean $enabled     = true,
) {
    if $enabled and $facts['sunet_firewalld_enabled'] == 'yes' {
      fail('firewalld already manages this host. Plan the migration before applying the SUNET nftables ruleset.')
    }

    package { 'nftables':
        ensure => 'present',
    }

    file { '/etc/nftables/':
        ensure => 'directory',
    }
    if ($enabled) {
      $service = 'running'
    } else {
      $service = 'stopped'
    }

    file { '/etc/nftables/conf.d/':
        ensure => 'directory',
        owner  => 'root',
        group  => 'root',
        mode   => '0755',
        source => 'puppet:///modules/sunet/nftables/nftables-conf.d-empty',
        notify => Service['nftables'],
    }

    if ($default_log) {
      file { '/etc/nftables/conf.d/999-log.nft':
        ensure => 'present',
        mode   => '0644',
        source => 'puppet:///modules/sunet/nftables/999-log.nft',
        notify => Service['nftables'],
      }
    }

    $config = $facts['os']['name'] ? {
      'AlmaLinux' => '/etc/sysconfig/nftables.conf',
      default     => '/etc/nftables.conf',
    }
    file { $config:
        ensure  => 'present',
        mode    => '0755',
        source  => 'puppet:///modules/sunet/nftables/nftables.conf',
        require => Package['nftables'],
        notify  => Service['nftables'],
    }

    service { 'nftables':
        ensure => $service,
        enable => $enabled,
    }
}
