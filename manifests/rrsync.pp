define sunet::rrsync(
  $user         = 'root',
  $manage_user  = false,
  $dir          = undef,
  $ssh_key      = undef,
  $ssh_key_type = undef
) {
  $safe_name = regsubst($title, '[^0-9A-Za-z.\-]', '-', 'G')
  $directory = $dir ? {
     undef   => $name,
     default => $dir
  }
  ensure_resource('exec','rrsync_unpack',{
    onlyif      => "test ! -f /usr/bin/rrsync",
    command     => "zcat /usr/share/doc/rsync/scripts/rrsync.gz > /usr/bin/rrsync && chmod a+rx /usr/bin/rrsync"
  })
  sunet::snippets::ssh_command { "${safe_name}_command":
    user         => $user,
    manage_user  => $manage_user,
    ssh_key      => $ssh_key,
    ssh_key_type => $ssh_key_type,
    command      => "/usr/bin/rrsync -ro ${directory}"
  }
}
