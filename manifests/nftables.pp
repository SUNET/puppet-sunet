class sunet::nftables {
    package { 'nftables':
        ensure => 'present',
    }

    file { '/etc/nftables/':
        ensure => 'directory',
    }

    file { '/etc/nftables/conf.d/':
        ensure => 'directory',
        recurse => true, # enable recursive directory management
        purge => true,   # purge all unmanaged junk
        force => true,   # also purge subdirs and links etc.
        owner => "root",
        group => "root",
        mode => "0644",
        source => "puppet:///sunet/nftables/nftables-conf.d-empty",
        notify  => Service['nftables'],
    }

    file { '/etc/nftables.conf':
        ensure  => 'present',
        replace => 'no',
        mode    => "755",
        source  => file('sunet/nftables/nftables.conf'),
        notify  => Service['nftables'],
    }

    service { 'nftables':
        ensure => 'running',
        enable => true,
    }
}

define nftables::rule(
    String $rule,
) {
   include ::nftables

   file { "/etc/nftables/conf.d/${name}.nft":
       ensure  => 'present',
       content => "$rule\n",
       notify  => Service['nftables'],
       require => Package['nftables'],
   }
}

#class nftables_nagiosnrpe {
#  nftables::rule { 'nagios_port_5666':
#        rule => 'add rule inet filter input ip saddr { 109.105.111.111/32 } tcp dport 5666 counter accept',
#    }
#}
