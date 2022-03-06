class sunet::nftables {
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

    file { '/etc/nftables.conf':
        ensure  => 'present',
        replace => 'no',
        mode    => '0755',
        source  => 'puppet:///modules/sunet/nftables/nftables.conf',
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
