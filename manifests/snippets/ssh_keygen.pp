# Ssh keygen
define sunet::snippets::ssh_keygen(
  $key_file=undef,
  $key_type='ed25519',
) {
  $_key_file = $key_file ? {
    undef   => $name,
    default => $key_file
  }
  exec { "${name}-ssh-key":
    command => "ssh-keygen -t ${key_type} -N '' -f ${_key_file}",
    onlyif  => "test ! -s ${_key_file}.pub -o ! -s ${_key_file}"
  }
}
