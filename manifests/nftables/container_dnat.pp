# Install the helper script used by defines that need to keep an
# nftables DNAT/forward rule pointed at a docker-compose-managed
# container whose IP address changes across `docker compose down`/`up`
# (i.e. every restart of a sunet::docker_compose_service unit, since its
# ExecStop runs `docker compose down`). See sunet::auth_server for a
# consumer example - it builds an ExecStartPost= line calling
# /usr/local/sbin/sunet_nft_container_dnat and passes it via
# $service_extras.
class sunet::nftables::container_dnat {
  file { '/usr/local/sbin/sunet_nft_container_dnat':
    ensure => 'file',
    owner  => 'root',
    group  => 'root',
    mode   => '0500',
    source => 'puppet:///modules/sunet/nftables/sunet_nft_container_dnat',
  }
}
