# Add a rule
define sunet::nftables::rule(
    String $rule,
) {
   include sunet::nftables

   file { "/etc/nftables/conf.d/${name}.nft":
      ensure  => 'present',
      content => "${rule}\n",
      notify  => Service['nftables'],
      require => Package['nftables'],
   }
}

#class nftables_nagiosnrpe {
#  nftables::rule { 'nagios_port_5666':
#        rule => 'add rule inet filter input ip saddr { 109.105.111.111/32 } tcp dport 5666 counter accept',
#    }
#}
