
class sunet::gitolite($username='git',$group='git',$ssh_key=undef) {
   ensure_resource('sunet::system_user', $username, {
      username   => $username,
      group      => $group,
      managehome => true,
      shell      => '/bin/bash' 
   })
   $gitolitehome = $username ? {
      'root'    => '/root/.gitolite',
      default   => "/home/${username}/.gitolite"
   }
   file {$gitolitehome:
      ensure    => directory,
      owner     => $username,
      group     => $group
   } ->
   case $ssh_key {
      undef: {
         file { "$gitolitehome/admin.pub":
            content => inline_template('<%= @ssh_key %>')
         }
      }
      default: {
         sunet::snippets::ssh_keygen { "$gitolitehome/admin": }
      }
   } ->
   package {'gitolite3': ensure => latest } ->
   exec {'gitolite-setup':
      command => "gitolite setup -pk $gitolitehome/admin.pub",
      user    => $username
   }
}
