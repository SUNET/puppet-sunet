# Rootless Quadlet host. The distribution's useradd allocates subordinate IDs
# for a regular local account. Never replace an existing container store's map.
class sunet::podman2 (
  Pattern[/^[a-z_][a-z0-9_-]*$/] $workload_user = 'barnbarn',
) {
  if $workload_user == 'root' {
    fail('A rootless workload requires a dedicated non-root account.')
  }
  include sunet::packages::podman
  case $facts['os']['family'] {
    'RedHat': {
      $packages = ['shadow-utils', 'passt', 'container-selinux', 'fuse-overlayfs']
    }
    'Debian': {
      $packages = ['uidmap', 'passt', 'dbus-user-session', 'fuse-overlayfs']
    }
    default: { fail("Unsupported Podman host OS: ${facts['os']['name']}") }
  }
  ensure_packages($packages)
  $home = "/home/${workload_user}"
  group { $workload_user: ensure => present }
  user { $workload_user:
    ensure     => present,
    gid        => $workload_user,
    groups     => [],
    membership => inclusive,
    home       => $home,
    managehome => true,
    shell      => '/bin/bash',
  }
  file { ["${home}/.config", "${home}/.config/containers", "${home}/.config/containers/systemd"]:
    ensure  => directory,
    owner   => $workload_user,
    group   => $workload_user,
    mode    => '0700',
    require => User[$workload_user],
  }
  exec { "enable linger for ${workload_user}":
    command => "/usr/bin/loginctl enable-linger ${workload_user}",
    creates => "/var/lib/systemd/linger/${workload_user}",
    require => User[$workload_user],
  }
}
