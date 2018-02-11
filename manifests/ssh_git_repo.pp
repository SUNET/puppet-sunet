define sunet::ssh_git_repo(
      $hostname    = 'github.com',
      $username    = 'github',
      $group       = 'github',
      $url         = undef,
      $id          = 'github',
      $manage_user = true,
      $manage_key  = true,
      $revision    = 'master',
      $ensure      = 'present'
) {
   if ($manage_user) {
      ensure_resource('group',"${group}")
      sunet::system_user { "${username}": 
         username  => "${username}",   
         group     => "${group}"
      }
   }
   $ssh_home = $username ? {
      'root'    => '/root/.ssh',
      default   => "/home/${username}/.ssh"
   }
   file { "${ssh_home}":
      ensure    => directory,
      mode      => '0700',
      owner     => "${username}",
      group     => "${group}"
   } -> 
   augeas {"ssh_config_set_host_identity":
      incl    => "${ssh_home}/config",
      lens    => 'Ssh.lns',
      changes => [
         "set /files${ssh_home}/config/Host ${hostname}",
         "set /files${ssh_home}/config/Host[.='${hostname}']/IdentityFile ${ssh_home}/${id}"
      ]
   } ->
   sunet::ssh_keyscan::host {$hostname: } ->
   vcsrepo { "${name}":
      ensure    => $ensure,
      provider  => git,
      source    => $url,
      user      => $username,
      revision  => $revision
   }
   if ($manage_key) {
      exec { "${title}-ssh-keygen":
         command => "ssh-keygen -N '' -C '${username}@${::fqdn}' -f '${ssh_home}/${id}' -t ed25519",
         user    => "${username}",
         onlyif  => "test ! -f ${ssh_home}/${id}"
      }
   }
}
