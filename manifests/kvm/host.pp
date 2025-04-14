# kvm::host
class sunet::kvm::host(
  Optional[String]         $nat_bridge_interface  = undef,
  Hash                     $vms                   = {},
) {

  file {
    '/etc/cosmos-manual-reboot':
      ensure => present,
  }
  package { [
    'bridge-utils',
    'cpu-checker',
    'libvirt-clients',
    'libvirt-daemon-system',
    'mtools',
    'numad',
    'ovmf',
    'qemu-system',
    'qemu-utils',
    'virtinst',
    'vlan',
  ]: ensure => 'present' }

  if $::facts['sunet_nftables_enabled'] != 'yes' {
    exec { 'fix_iptables_forwarding_for_guests':
      command => 'sed -i "/^COMMIT/i-I FORWARD -m physdev --physdev-is-bridged -j ACCEPT" /etc/ufw/before.rules; ufw reload',
      path    => ['/usr/sbin', '/usr/bin', '/sbin', '/bin', ],
      unless  => 'grep -q -- "^-I FORWARD -m physdev --physdev-is-bridged -j ACCEPT" /etc/ufw/before.rules',
      onlyif  => 'test -f /etc/ufw/before.rules',
    }

    exec { 'fix_ip6tables_forwarding_for_guests':
      command => 'sed -i "/^COMMIT/i-I FORWARD -m physdev --physdev-is-bridged -j ACCEPT" /etc/ufw/before6.rules; ufw reload',
      path    => ['/usr/sbin', '/usr/bin', '/sbin', '/bin', ],
      unless  => 'grep -q -- "^-I FORWARD -m physdev --physdev-is-bridged -j ACCEPT" /etc/ufw/before6.rules',
      onlyif  => 'test -f /etc/ufw/before6.rules',
    }
  }

  sunet::snippets::file_line {
    'load_vlan_module_at_boot':
      filename => '/etc/modules',
      line     => '8021q',
      ;
  }

  if $nat_bridge_interface != undef {
    if $facts['sunet_nftables_opt_in'] == 'yes' or ($facts['os']['name'] == 'Ubuntu' and versioncmp($facts['os']['release']['full'], '22.04') >= 0) { # lint:ignore:140chars
      file { '/usr/local/bin/sunet-kvm-modify-forwardmode':
          content => file('sunet/kvm/sunet-modify-kvm-forwardmode'),
          mode    => '0755',
      }

      exec { '/usr/local/bin/sunet-kvm-modify-forwardmode default nat open':
        onlyif  => "virsh net-dumpxml default --inactive | grep -q \"<forward mode='nat'/>\""
      }

      sunet::nftables::kvm_nat { 'sunet::kvm::host': bridge_name => $nat_bridge_interface }
    }
  }

  create_resources('sunet::kvm::cloudimage', $vms)

}
