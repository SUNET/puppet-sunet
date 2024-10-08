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
  sunet::ssh_host_credential { "${title}-ssh-cred":
      hostname    => $hostname,
      username    => $username,
      group       => $group,
      id          => $id,
      manage_user => $manage_user,
      manage_key  => $manage_key,
  }
  -> vcsrepo { $name:
      ensure   => $ensure,
      provider => git,
      source   => $url,
      user     => $username,
      revision => $revision
  }
}
