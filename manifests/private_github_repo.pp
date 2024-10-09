# github repo
define sunet::private_github_repo(
      $username    = 'github',
      $group       = 'github',
      $url         = undef,
      $id          = 'github',
      $manage_user = true,
      $manage_key  = true,
      $revision    = 'master'
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
  file { $ssh_home:
      ensure => directory,
      mode   => '0700',
      owner  => $username,
      group  => $group
  }
  -> file { "${ssh_home}/config":
      ensure  => 'file',
      content => "Host github.com\n    IdentityFile ~/.ssh/${id}\n",
      mode    => '0644',
      owner   => $username,
      group   => $group
  }
  -> sunet::ssh_keyscan::host {'github.com': }
  -> vcsrepo { $name:
      ensure   => latest,
      provider => git,
      source   => $url,
      user     => $username,
      revision => $revision
  }
  if ($manage_key) {
      exec { "${title}-ssh-keygen":
        command => "ssh-keygen -N '' -C '${username}@${facts['networking']['fqdn']}' -f '${ssh_home}/${id}' -t ecdsa",
        user    => $username,
        onlyif  => "test ! -f ${ssh_home}/${id}"
      }
  }
}
