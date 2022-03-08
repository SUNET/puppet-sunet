# set up DNAT port forwarding of $port to Docker
define sunet::nftables::docker_expose(
  Variant[String, Array[String]] $allow_clients, # Allow traffic 'from' this IP (or list of IP:s).
  Variant[Integer, String] $port,  # Allow traffic to this port (or list of ports).
  String $docker_v4 = '172.16.0.2',
  String $docker_v6 = 'fd00::2',
) {
  $safe_name = regsubst($title, '[^0-9A-Za-z_]', '_', 'G')

  # Used in template
  $allow_clients_v4 = filter(flatten([$allow_clients])) | $this | { is_ipaddr($this, 4) }
  $allow_clients_v6 = filter(flatten([$allow_clients])) | $this | { is_ipaddr($this, 6) }
  $dport = sunet::format_nft_set('dport', $port)

  file {
    "/etc/nftables/conf.d/600-docker_expose-${safe_name}.nft":
      ensure  => file,
      mode    => '0400',
      content => template('sunet/nftables/docker_expose.nft.erb'),
      ;
  }
}
