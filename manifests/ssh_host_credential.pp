define sunet::ssh_host_credential(
      $hostname    = 'localhost',
      $hostalias   = undef,
      $remote_user = undef,
      $username    = 'root',
      $group       = 'root',
      $id          = 'default',
      $manage_user = true,
      $manage_key  = true,
      $revision    = 'master',
      $ensure      = 'present',
      $ssh_privkey = undef
) {
  if ($manage_user) {
      ensure_resource('group',$group)
      sunet::system_user { $username:
        username => $username,
        group    => $group
      }
  }
  $ssh_home = $username ? {
      'root'    => '/root/.ssh',
      default   => "/home/${username}/.ssh"
  }
  $_hostalias = $hostalias ? {
      undef     => $hostname,
      default   => $hostalias
  }
  ensure_resource('file', $ssh_home, {
      ensure    => directory,
      mode      => '0700',
      owner     => $username,
      group     => $group
  });
  $remote_user_changes = $remote_user ? {
      undef     => [],
      default   => "set Host[.='${_hostalias}']/user ${remote_user}"
  }
  $changes = flatten([["set Host[last()+1] ${_hostalias}",
                        "set Host[.='${_hostalias}']/IdentityFile ${ssh_home}/${id}"],
                        $remote_user_changes])
  augeas {"ssh_config_${hostname}":
      incl    => "${ssh_home}/config",
      context => "/files${ssh_home}/config",
      lens    => 'Ssh.lns',
      changes => $changes,
      onlyif  => "match Host[.='${_hostalias}'] size == 0"
  }
  -> sunet::ssh_keyscan::host {$hostname: }
  if ($ssh_privkey) {
      file { "${ssh_home}/${id}":
        content => inline_template('<%= @ssh_privkey %>'),
        mode    => '0400',
        owner   => $username,
        group   => $group
      }
  } elsif ($manage_key) {
      exec { "${title}-ssh-keygen":
        command => "ssh-keygen -N '' -C '${username}@${facts['networking']['fqdn']}' -f '${ssh_home}/${id}' -t ed25519",
        user    => $username,
        onlyif  => "test ! -f ${ssh_home}/${id}"
      }
  }
}
