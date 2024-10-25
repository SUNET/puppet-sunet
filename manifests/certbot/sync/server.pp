# the certbot sync server
class sunet::certbot::sync::server(
){
  $client_ips = lookup('certbot_sync_client_ips', undef, undef, [])
  $client_ips.each |$ip| {
    sunet::nftables::allow { "certbot_sync_client_${ip}":
      from => $ip,
      port => 22,
    }
  }
  sunet::ssh_keys { 'sync_client-keys':
    config            => safe_hiera('certbot_sync_client_ssh_keys_mapping', {}),
    key_database_name => 'certbot_sync_client_ssh_keys_db'
  }
}
