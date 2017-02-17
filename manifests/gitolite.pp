
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
   case $ssh_key {
      undef: {
         file { "$home/admin.pub":
            content => inline_template('<%= @ssh_key %>')
         }
      }
      default: {
         sunet::snippets::ssh_keygen { "$home/admin": }
      }
   } ->
   package {'gitolite3': ensure => latest } ->
   exec {'gitolite-setup':
      command     => "gitolite setup -pk $home/admin.pub",
      user        => $username,
      environment => ["HOME=$home"]
   }
}
