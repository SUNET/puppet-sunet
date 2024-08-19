# the certbot sync client
class sunet::certbot::sync::client(
){
  $key_path = '/root/.ssh/id_acmed_agent'

  exec { '/usr/bin/mkdir -p /opt/certbot/libexec':
    unless  => '/usr/bin/test -d /opt/certbot/libexec'
  }
  file { '/opt/certbot/libexec/acme-dns-fetch-from-primary.sh':
    ensure  => file,
    mode    => '0700',
    content => template('sunet/certbot/acme-dns-fetch-from-primary.sh.erb'),
  }
  sunet::scriptherder::cronjob { 'fetch-cert-from-primary':
    cmd           => '/opt/certbot/libexec/acme-dns-fetch-from-primary.sh',
    minute        => '27',
    hour          => '*',
    ok_criteria   => ['exit_status=0', 'max_age=3h'],
    warn_criteria => ['exit_status=0', 'max_age=5h'],
  }
  if lookup('acmed_agent_ssh_key', undef, undef, undef) {
    ensure_resource('sunet::snippets::secret_file', $key_path, {
      hiera_key => 'acmed_agent_ssh_key',
    })
  } else {
    if (!find_file($key_path)){
      sunet::snippets::ssh_keygen{$key_path:}
    }
  }
}
