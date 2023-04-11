# Create system users for the various services on a load balancer
#
# This has to be a class for the obscure reason that when docker is told to run something
# as a user(name), it looks in /etc/passwd _in the container_, __before mounting volumes__
# for that user(name) - which won't work. Therefor, docker-compose files need to specify
# uid/gid instead :/ and thus this has to be a class so the templates can look up the uid/gid.
class sunet::frontend::load_balancer::users(
  Integer $frontend,
  Integer $fe_api,
  Integer $fe_monitor,
  Integer $fe_config,
  Integer $haproxy,
  Integer $telegraf,
  Integer $varnish,
) {
  # uid/gids looked up from compose files
  $user2uid = {
    'frontend' => $frontend,
    'fe-api' => $fe_api,
    'fe-monitor' => $fe_monitor,
    'fe-config' => $fe_config,
    'haproxy' => $haproxy,
    'telegraf' => $telegraf,
    'varnish' => $varnish,
  }

  # Ensure this group is present before trying to add users fe-config and fe-monitor to it
  ensure_resource('group', 'haproxy', {
    ensure => present,
    name   => 'haproxy',
    gid    => $user2uid['haproxy'],
  })

  each($user2uid) | $username, $uidgid | {
    $groups = $username ? {
        'frontend'   => undef,
        'telegraf'   => undef,
        'fe-config'  => ['haproxy'],
        'fe-monitor' => ['haproxy'],
        default      => ['frontend'],
      }
    ensure_resource ( 'sunet::misc::system_user', $username, {
      group    => $username,
      username => $username,
      uid      => $uidgid,
      gid      => $uidgid,
      groups   => $groups,
    })
  }
}
