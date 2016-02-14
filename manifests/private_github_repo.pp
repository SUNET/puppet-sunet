define sunet::private_github_repo(
      username    = 'github',
      group       = 'github',
      url         = undef,
      id          = 'github'
      manage_user = true,
      manage_key  = true,
) {
   if ($manage_user) {
      ensure_resource('group',"${group}")
      sunet::system_user { "${username}": 
         username  => "${username}",   
         group     => "${group}"
      }
   }
   file { "/home/${username}/.ssh":
      ensure    => directory,
      mode      => '0700',
      owner     => "${username}",
      group     => "${group}"
   } -> 
   file { "/home/${username}/.ssh/config":
      ensure    => 'file',
      content   => "Host github.com\n    IdentityFile ~/.ssh/${id}\n",
      mode      => '0644',
      owner     => "${username}",
      group     => "${group}"
   } ->
   exec { 'update-github-ssh-keys':
      command   => 'ssh-keyscan -H github.com > /etc/ssh/ssh_known_hosts'
   } -> 
   vcsrepo { "${name}":
      ensure    => present,
      provider  => git,
      source    => "${url}",
      user      => "${username}"
   }
   if ($manage_key) {
      exec { "${title}-ssh-keygen":
         command => "ssh-keygen -N '' -C '${username}@${::fqdn}' -f '/home/${username}/.ssh/${id}' -t ecdsa",
         user    => "${username}",
         onlyif  => "test ! -f /home/${username}/.ssh/${id}"
      }
   }
}
