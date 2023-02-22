# Create a file with secret content retrieved from hiera.
define sunet::misc::create_key_file(
  String           $hiera_key,
  Optional[String] $path       = undef,
  String           $owner      = 'root',
  String           $group      = 'root',
  String           $mode       = '0440',
) {
  $_path = $path ? {
    undef   => $name,
    default => $path,
  }

  $key_content = hiera($hiera_key, 'NOT_SET_IN_HIERA')

  if $key_content == 'NOT_SET_IN_HIERA' {
    warning ("Key file data key '${hiera_key}' not set in hiera")
  } else {
    ensure_resource('file', $_path, {
        ensure    => file,
        owner     => $owner,
        group     => $group,
        mode      => $mode,
        content   => $key_content,
        show_diff => false,
    })
  }
}
