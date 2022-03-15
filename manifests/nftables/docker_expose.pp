# set up DNAT port forwarding of $port to Docker
define sunet::nftables::docker_expose(
  Variant[String, Array[String]] $allow_clients, # Allow traffic 'from' this IP (or list of IP:s).
  Variant[Integer, String] $port,  # Allow traffic to this port (or list of ports).
  Enum['tcp', 'udp'] $proto = 'tcp',
  String $docker_v4 = '172.16.0.2',
  String $docker_v6 = 'fd00::2',
) {
  $safe_name = regsubst($title, '[^0-9A-Za-z_]', '_', 'G')

  $allow_clients_v4 = filter(flatten([$allow_clients])) | $this | { is_ipaddr($this, 4) or $this == 'any' }
  $allow_clients_v6 = filter(flatten([$allow_clients])) | $this | { is_ipaddr($this, 6) or $this == 'any' }

  # Variables used in template
  $saddr_v4 = sunet::format_nft_set('ip saddr', $allow_clients_v4)
  $saddr_v6 = sunet::format_nft_set('ip6 saddr', $allow_clients_v6)
  $dport = sunet::format_nft_set('dport', $port)

  file {
    "/etc/nftables/conf.d/600-docker_expose-${safe_name}.nft":
      ensure  => file,
      mode    => '0400',
      content => template('sunet/nftables/docker_expose.nft.erb'),
      notify  => Service['nftables'],
      ;
  }
}
