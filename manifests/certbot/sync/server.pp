# the certbot sync server
class sunet::certbot::sync::server(
){
  $agent_ips = lookup('acmed_agent_ips', undef, undef, [])
  $agent_ips.each |$ip| {
    sunet::nftables::allow { "allow_agent_${ip}":
      from => $ip,
      port => 22,
    }
  }
  sunet::ssh_keys { 'agent-keys':
    config            => safe_hiera('acmed_agent_ssh_keys_mapping', {}),
    key_database_name => 'acmed_agent_ssh_keys_db'
  }
}
