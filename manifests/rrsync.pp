define sunet::rrsync(
  $user         = 'root',
  $manage_user  = false,
  $dir          = undef,
  $ssh_key      = undef,
  $ssh_key_type = undef
) {
  $safe_name = regsubst($name, '[^0-9A-Za-z.\-]', '-', 'G')

  $directory = $dir ? {
     undef   => $name,
     default => $dir
  }

  if ($manage_user) {
    ensure_resource('group',"${user}")
    sunet::system_user { "${user}": 
      username  => "${user}",
      group     => "${user}"
    }
  }

  $ssh_home = $user ? {
    'root'    => '/root/.ssh',
    default   => "/home/${user}/.ssh"
  }

  ensure_resource('file',$ssh_home,{
      ensure => directory,
      mode      => '0700',
      owner     => "${user}",
      group     => "${user}"
  })

  ensure_resource('exec','rrsync_unpack',{
    only_if     => "test ! -f /usr/bin/rrsync",
    command     => "zcat /usr/share/doc/rsync/scripts/rrsync.gz > /usr/bin/rrsync && chmod a+rx /usr/bin/rrsync"
  })

  ssh_authorized_key { "${safe_name}_rrsync":
    ensure  => present,
    user    => $user,
    type    => $ssh_key_type,
    key     => $ssh_key,
    target  => "${ssh_home}/authorized_keys",
    options => [
      "command=\"/usr/bin/rrsync -ro ${directory}\"",
      "no-agent-forwarding",
      "no-port-forwarding",
      "no-pty",
      "no-user-rc",
      "no-X11-forwarding"
    ]
  }
}
