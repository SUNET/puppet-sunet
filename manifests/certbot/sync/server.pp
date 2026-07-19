# the certbot sync server
class sunet::certbot::sync::server(
){
  # rrsync jail exposed to sync clients. Populated by the certbot deploy hook
  # below, which installs only the certs whose domain is marked exportable in
  # /etc/letsencrypt/acmedns.json. rrsync can only jail a directory, it cannot
  # filter within one, so the filtering lives in what the hook copies here.
  $jail = '/opt/certbot-sync/export'

  # The deploy hook parses acmedns.json with jq.
  include sunet::packages::jq

  $client_ips = lookup('certbot_sync_client_ips', undef, undef, [])
  $client_ips.each |$ip| {
    sunet::nftables::allow { "certbot_sync_client_${ip}":
      from => $ip,
      port => 22,
    }
  }

  # The server owns the rrsync forced command so it always jails clients to the
  # export dir. We take the raw key material from the key database and inject our
  # own options, ignoring any command that may be set there.
  $forced_command = "/usr/bin/rrsync -ro ${jail}"
  $forced_options = join([
    "command=\"${forced_command}\"",
    'no-agent-forwarding',
    'no-port-forwarding',
    'no-pty',
    'no-user-rc',
    'no-X11-forwarding',
  ], ',')

  $raw_keydb = safe_hiera('certbot_sync_client_ssh_keys_db', {})
  $sync_keydb = Hash($raw_keydb.map |$keyname, $keydata| {
    [$keyname, {
      'key'     => $keydata['key'],
      'type'    => pick($keydata['type'], 'ssh-rsa'),
      'name'    => pick($keydata['name'], $keyname),
      'options' => $forced_options,
    }]
  })

  sunet::ssh_keys { 'sync_client-keys':
    config   => safe_hiera('certbot_sync_client_ssh_keys_mapping', {}),
    database => $sync_keydb,
  }

  # The export dir clients rsync from. Contents are managed by the deploy hook,
  # so we only manage the dirs themselves (no recurse/purge).
  ensure_resource('file', '/opt/certbot-sync', {
    ensure => directory, mode => '0700', owner => 'root', group => 'root',
  })
  file { '/opt/certbot-sync/export':
    ensure => directory,
    mode   => '0700',
    owner  => 'root',
    group  => 'root',
  }
  file { '/opt/certbot-sync/export/live':
    ensure => directory,
    mode   => '0700',
    owner  => 'root',
    group  => 'root',
  }

  # certbot deploy hook: on each renewal, export the cert iff its domain is
  # marked exportable in acmedns.json.
  include sunet::packages::certbot
  file { '/etc/letsencrypt/renewal-hooks/deploy/certbot-sync-export':
    ensure  => file,
    mode    => '0700',
    content => file('sunet/certbot-sync/certbot-sync-export.sh'),
    before  => Class['sunet::certbot::acmed']
  }
}
