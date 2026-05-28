# rrsync
define sunet::rrsync(
  String $ssh_key,
  String $ssh_key_type,
  Optional[String] $dir       = undef,  # defaults to $name
  String $user                = 'root',
  Boolean $manage_user        = false,
  Boolean $ro                 = true,
  Boolean $use_sunet_ssh_keys = false,
) {
  $safe_name = regsubst($title, '[^0-9A-Za-z.\-]', '-', 'G')
  $directory = pick($dir, $name)
  $_flags = $ro ? {
    false   => '',
    default => '-ro'
  }
  ensure_resource('exec','rrsync_unpack',{
    onlyif  => 'test ! -f /usr/bin/rrsync',
    command => 'zcat /usr/share/doc/rsync/scripts/rrsync.gz > /usr/bin/rrsync && chmod a+rx /usr/bin/rrsync',
  })
  if $use_sunet_ssh_keys {
    # ssh_command2 will set up SSH keys using sunet::ssh_keys, which is how it is done in nunoc-ops
    sunet::snippets::ssh_command2 { "${safe_name}_command":
      user         => $user,
      manage_user  => $manage_user,
      ssh_key      => $ssh_key,
      ssh_key_type => $ssh_key_type,
      command      => "/usr/bin/rrsync ${_flags} ${directory}"
    }
  } else {
    sunet::snippets::ssh_command { "${safe_name}_command":
      user         => $user,
      manage_user  => $manage_user,
      ssh_key      => $ssh_key,
      ssh_key_type => $ssh_key_type,
      command      => "/usr/bin/rrsync ${_flags} ${directory}"
    }
  }
}
