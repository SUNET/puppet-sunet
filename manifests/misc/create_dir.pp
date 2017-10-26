# Create a directory.
define eduid::misc::create_dir(
  $owner,
  $group,
  $mode,
) {
  $req_user = $owner ? {
    # users not created in Puppet, so can't require them
    'root'     => [],
    'www-data' => [],
    default    => User[$owner],
  }
  $req_group = $group ? {
    # groups not created in Puppet, so can't require them
    'root'     => [],
    'www-data' => [],
    default    => Group[$group],
  }

  # puppet is too dumb to create directories recursively,
  # so create it using mkdir and then use 'file' (hah!) to
  # fix the owner and permissions
  ensure_resource('exec', "sudo-make-me-a-sandwich_${name}", {
    command => "/bin/mkdir -p ${name}",
    unless  => "/usr/bin/test -d ${name}",
  })

  $require = flatten([$req_user,
                      $req_group,
                      Exec["sudo-make-me-a-sandwich_${name}"],
                      ])

  file { $name:
    ensure  => 'directory',
    mode    => $mode,
    owner   => $owner,
    group   => $group,
    require => $require,
  }
}
