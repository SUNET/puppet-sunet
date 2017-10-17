# Create a file with secret content retrieved from Hiera.
define sunet::misc::create_key_file(
  $hiera_key,
  $owner      = 'root',
  $group      = 'root',
  $mode       = '0440',
) {

  $key_content = hiera($hiera_key, 'NOT_SET_IN_HIERA')

  if $key_content == 'NOT_SET_IN_HIERA' {
    warning ("Key file data key '${hiera_key}' not set in Hiera")
  }

  file { $name :
    ensure              => file,
    owner               => $owner,
    group               => $group,
    mode                => $mode,
    content             => $key_content,
  }
}
