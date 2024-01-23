# set up DNAT port forwarding of $port to Docker
# @param allow_clients  Clients to allow traffic from. List of IP addresses or CIDR blocks.
# @param port           Port to allow traffic to.
# @param proto          Protocol to allow traffic for.
# @param dnat_v4_addr   IPv4 address of Docker bridge (the IP address of docker on the to_docker veth pair).
# @param dnat_v6_addr   IPv6 address to use for DNAT. Docker won't set up DNAT for IPv6, so provide the containers v6 addr here.
# @param dnat_v6_port   Port to use for v6 DNAT. Docker won't set up DNAT for IPv6, so provide the containers v6 port here.
define sunet::nftables::docker_expose (
  Variant[String, Array[String]] $allow_clients, # Allow traffic 'from' this IP (or list of IP:s).
  Variant[Integer, String] $port,  # Allow traffic to this port
  Enum['tcp', 'udp'] $proto = 'tcp',
  String $iif = 'eth0',
  String $dnat_v4_addr = '172.16.0.2',
  String $dnat_v6_addr = 'fd00::2',
  Variant[Integer, String] $dnat_v6_port = $port,
) {
  $safe_name = regsubst($title, '[^0-9A-Za-z_]', '_', 'G')

  $docker_class = $::facts['dockerhost2'] ? {
    no => 'sunet::dockerhost',
    default => 'sunet::dockerhost2',
  }
  if ($docker_class == 'sunet::dockerhost') {

    $allow_clients_v4 = filter(flatten([$allow_clients])) | $this | { is_ipaddr($this, 4) or $this == 'any' }
    $allow_clients_v6 = filter(flatten([$allow_clients])) | $this | { is_ipaddr($this, 6) or $this == 'any' }

    # Variables used in template
    $saddr_v4 = sunet::format_nft_set('ip saddr', $allow_clients_v4)
    $daddr_v4 = sunet::format_nft_set('ip daddr', [$dnat_v4_addr])
    $saddr_v6 = sunet::format_nft_set('ip6 saddr', $allow_clients_v6)
    $daddr_v6 = sunet::format_nft_set('ip6 daddr', [$dnat_v6_addr])
    $dport = sunet::format_nft_set('dport', $port)
    $v6_dnat_dport = sunet::format_nft_set('dport', $dnat_v6_port)

    if ! has_key($::facts['networking']['interfaces'], 'to_docker') {
      notice('No to_docker interface found, not setting up the DNAT rules for Docker (will probably work next time)')
    } else {
      file {
        "/etc/nftables/conf.d/600-docker_expose-${safe_name}.nft":
          ensure  => file,
          mode    => '0400',
          content => template('sunet/nftables/600-docker_expose.nft.erb'),
          notify  => service['nftables'],
          ;
      }
    }
  } else {
      file {
        "/etc/nftables/conf.d/600-docker_expose-${safe_name}.nft":
          ensure => absent,
          notify => service['nftables'],
          ;
      }
      sunet::nftables::allow { "expose-allow-${safe_name}":
        from => 'any',
        port => $port,
      }
  }
}
