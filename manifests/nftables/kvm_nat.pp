# Configure SNAT for default network on KVM servers
define sunet::nftables::kvm_nat(
  String $bridge_name = 'virbr0',
  String $bridge_v4_cidr = '192.168.122.0/24',
) {

  file {
    "/etc/nftables/conf.d/700-kvm_nat-${bridge_name}.nft":
      ensure  => file,
      mode    => '0400',
      content => template('sunet/nftables/700-kvm_nat.nft.erb'),
      notify  => Service['nftables'],
  }
}
