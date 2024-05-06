# Set up prerequisites for Ethernet LACP bonding of eth0 and eth1,
# for all physical hosts that are running Ubuntu.
#
# Bonding requires setup in /etc/network/interfaces as well.
#
define sunet::snippets::ethernet_bonding() {
  if $facts['is_virtual'] == 'false' and $facts['os']['name'] == 'Ubuntu' {
    if $facts['os']['release']['full'] <= '12.04' {
      package {'ifenslave': ensure => 'present' }
    } else {
      package {'ifenslave-2.6': ensure => 'present' }
    }

    sunet::snippets::file_line { 'load_module_at_boot':
      filename => '/etc/modules',
      line     => 'bonding',
    }
  }
}
