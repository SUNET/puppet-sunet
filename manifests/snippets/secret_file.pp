#Secret file
define sunet::snippets::secret_file(
  $hiera_key = undef,
  $path      = undef,
  $owner     = root,
  $group     = root,
  $mode      = '0400',
  $base64    = false
) {
  require stdlib
  $thefile = $path ? {
    undef    => $name,
    default  => $path
  }
  $safe_key = regsubst($hiera_key, '[^0-9A-Za-z_]', '_', 'G')
  $data = lookup($hiera_key, undef, undef, lookup($safe_key, undef, undef, undef))
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
