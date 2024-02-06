#Secret file
define sunet::snippets::secret_file(
  $hiera_key = undef,
  $path      = undef,
  $owner     = root,
  $group     = root,
  $mode      = '0400',
  $base64    = false
) {
  $thefile = $path ? {
    undef    => $name,
    default  => $path
  }
  $safe_key = regsubst($hiera_key, '[^0-9A-Za-z_]', '_', 'G')
  $default_data_from_safe_key = lookup($safe_key, undef, undef, undef)
  $data = lookup($hiera_key, undef, undef, $default_data_from_safe_key)
  $decoded_data = $base64 ? {
    true     => base64('decode',$data),
    default  => $data
  }
  file { $thefile:
    owner   => $owner,
    group   => $group,
    mode    => $mode,
    content => inline_template('<%= @decoded_data %>')
  }
}
