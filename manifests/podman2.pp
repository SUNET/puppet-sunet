# Rootless Quadlet host. The distribution's useradd allocates subordinate IDs
# for a regular local account. Never replace an existing container store's map.
# Root operators can use bb for the workload user's Podman store and mgr for
# its systemd user manager. From /root, bb starts in the workload user's home.
class sunet::podman2 (
  Pattern[/\A[a-z_][a-z0-9_-]*\z/] $workload_user = 'barnbarn',
  Boolean $lockdown = false,
) {
  if $workload_user == 'root' {
    fail('A rootless workload requires a dedicated non-root account.')
  }
  if $lockdown {
    if $facts['os']['name'] != 'AlmaLinux' or $workload_user != 'barnbarn' {
      fail('podman2 lockdown requires AlmaLinux and the dedicated barnbarn account')
    }
    contain sunet::podman2::lockdown
  }
  include sunet::packages::podman
  case $facts['os']['family'] {
    'RedHat': {
      $account_packages = ['shadow-utils', 'util-linux']
      $packages = ['passt', 'container-selinux', 'fuse-overlayfs']
    }
    'Debian': {
      $account_packages = ['passwd', 'login']
      $packages = ['uidmap', 'passt', 'dbus-user-session', 'fuse-overlayfs']
    }
    default: { fail("Unsupported Podman host OS: ${facts['os']['name']}") }
  }
  ensure_packages($account_packages + $packages)
  $home = "/home/${workload_user}"
  group { $workload_user: ensure => present }
  Package[$account_packages] -> Group[$workload_user]
  user { $workload_user:
    ensure     => present,
    gid        => $workload_user,
    groups     => [],
    membership => inclusive,
    home       => $home,
    managehome => true,
    shell      => '/usr/sbin/nologin',
  }
  # Keep a pre-existing password hash locked without replacing it on each run.
  exec { "lock password for ${workload_user}":
    command => ['/usr/sbin/usermod', '--lock', $workload_user],
    unless  => "/usr/bin/getent shadow ${workload_user} | /usr/bin/grep -Eq '^[^:]+:[!*]'",
    require => User[$workload_user],
  }
  file { [$home, "${home}/.config", "${home}/.config/containers", "${home}/.config/containers/systemd"]:
    ensure  => directory,
    owner   => $workload_user,
    group   => $workload_user,
    mode    => '0700',
    require => Exec["lock password for ${workload_user}"],
  }
  exec { "enable linger for ${workload_user}":
    command => "/usr/bin/loginctl enable-linger ${workload_user}",
    creates => "/var/lib/systemd/linger/${workload_user}",
    require => File[$home],
  }

  ['bb', 'mgr'].each |String $command| {
    file { "/usr/local/sbin/${command}":
      ensure  => file,
      owner   => 'root',
      group   => 'root',
      mode    => '0755',
      content => template("sunet/podman2/${command}.erb"),
      require => [Class['sunet::packages::podman'], Exec["enable linger for ${workload_user}"]],
    }
  }
}
