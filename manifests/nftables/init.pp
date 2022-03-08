# Setup nftables on a host
class sunet::nftables(
  Boolean $default_log = true,
) {
    package { 'nftables':
        ensure => 'present',
    }

    file { '/etc/nftables/':
        ensure => 'directory',
    }

    file { '/etc/nftables/conf.d/':
        ensure => 'directory',
        owner  => 'root',
        group  => 'root',
        mode   => '0644',
        source => 'puppet:///modules/sunet/nftables/nftables-conf.d-empty',
        notify => Service['nftables'],
    }

    if ($default_log) {
      file { '/etc/nftables/conf.d/999-log.nft':
        ensure => 'present',
        mode   => '0755',
        source => 'puppet:///modules/sunet/nftables/999-log.nft',
        notify => Service['nftables'],
      }
    }

    file { '/etc/nftables.conf':
        ensure => 'present',
        mode   => '0755',
        source => 'puppet:///modules/sunet/nftables/nftables.conf',
        notify => Service['nftables'],
    }

    service { 'nftables':
        ensure => 'running',
        enable => true,
    }
}
