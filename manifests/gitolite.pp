
class sunet::gitolite($username='git',$group='git',$ssh_key=undef) {
   ensure_resource('sunet::system_user', $username, {
      username   => $username,
      group      => $group,
      managehome => true,
      shell      => '/bin/bash' 
   })
   $home = $username ? {
      'root'    => '/root',
      default   => "/home/${username}"
   }
   file { ["$home/.gitolite","$home/.gitolite/logs"]: 
      ensure => directory,
      owner  => $username,
      group  => $group
   } ->
   case $ssh_key {
      undef,"": {
         sunet::snippets::ssh_keygen { "$home/admin": }
      }
      default: {
         file { "$home/admin.pub":
            content => inline_template('<%= @ssh_key %>')
         }
      }
   } ->
   package {'gitolite3': ensure => latest } ->
   exec {'gitolite-setup':
      command     => "gitolite setup -pk $home/admin.pub",
      user        => $username,
      environment => ["HOME=$home"]
   }
}
