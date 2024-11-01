# the certbot sync client
class sunet::certbot::sync::client(
){
  $key_path = '/root/.ssh/id_certbot_sync_client'

  exec { '/usr/bin/mkdir -p /opt/certbot/libexec':
    unless  => '/usr/bin/test -d /opt/certbot/libexec'
  }
  exec { '/usr/bin/mkdir -p /opt/certbot/letsencrypt':
    unless  => '/usr/bin/test -d /opt/certbot/letsencrypt'
  }
  exec { '/usr/bin/mkdir -p /opt/certbot/renewal-hooks/deploy':
    unless  => '/usr/bin/test -d /opt/certbot/renewal-hooks/deploy'
  }
  file { '/opt/certbot/libexec/certbot-sync-from-server.sh':
    ensure  => file,
    mode    => '0700',
    content => template('sunet/certbot/certbot-sync-from-server.sh.erb'),
  }
  sunet::scriptherder::cronjob { 'certbot-sync-from-server':
    cmd           => '/opt/certbot/libexec/certbot-sync-from-server.sh',
    minute        => '27',
    hour          => '*',
    ok_criteria   => ['exit_status=0', 'max_age=3h'],
    warn_criteria => ['exit_status=0', 'max_age=5h'],
  }
  if lookup('certbot_sync_client_ssh_key', undef, undef, undef) {
    ensure_resource('sunet::snippets::secret_file', $key_path, {
      hiera_key => 'certbot_sync_client_ssh_key',
    })
  } else {
    if (!find_file($key_path)){
      sunet::snippets::ssh_keygen{$key_path:}
    }
  }
}
