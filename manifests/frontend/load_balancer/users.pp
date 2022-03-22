# Create system users for the various services on a load balancer
#
# This has to be a class for the obscure reason that when docker is told to run something
# as a user(name), it looks in /etc/passwd _in the container_, __before mounting volumes__
# for that user(name) - which won't work. Therefor, docker-compose files need to specify
# uid/gid instead :/ and thus this has to be a class so the templates can look up the uid/gid.
class sunet::frontend::load_balancer::users(
  Integer $base_uidgid = safe_hiera('sunet_frontend_load_balancer_base_uidgid', 800),
) {
  # uid/gids looked up from compose files
  $user2uid = {
    'frontend' => $base_uidgid + 0,
    'fe-api' => $base_uidgid + 1,
    'fe-monitor' => $base_uidgid + 2,
    'fe-config' => $base_uidgid + 3,
    'haproxy' => $base_uidgid + 10,
    'telegraf' => $base_uidgid + 11,
  }

  each($user2uid) | $username, $uidgid | {
    $groups = $username ? {
        'frontend' => undef,
        'telegraf' => undef,
        default    => ['frontend'],
      }
    sunet::misc::system_user { $username:
      group    => $username,
      username => $username,
      uid      => $uidgid,
      gid      => $uidgid,
      groups   => $groups,
    }
  }
}
