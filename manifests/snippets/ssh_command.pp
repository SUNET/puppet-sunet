# Ssh command
define sunet::snippets::ssh_command(
  $user         = 'root',
  $manage_user  = false,
  $ssh_key      = undef,
  $ssh_key_type = undef,
  $command      = 'ls /tmp'
) {
  $safe_name = regsubst($name, '[^0-9A-Za-z.\-]', '-', 'G')

  if ($manage_user) {
    ensure_resource('group',$user)
    sunet::system_user { $user:
      username => $user,
      group    => $user
    }
  }

  $ssh_home = $user ? {
    'root'    => '/root/.ssh',
    default   => "/home/${user}/.ssh"
  }

  ensure_resource('file',$ssh_home,{
      ensure => directory,
      mode      => '0700',
      owner     => $user,
      group     => $user
  })

  ssh_authorized_key { "${safe_name}_key":
    ensure  => present,
    user    => $user,
    type    => $ssh_key_type,
    key     => $ssh_key,
    target  => "${ssh_home}/authorized_keys",
    options => [
      "command=\"${command}\"",
      'no-agent-forwarding',
      'no-port-forwarding',
      'no-pty',
      'no-user-rc',
      'no-X11-forwarding'
    ]
  }
}
