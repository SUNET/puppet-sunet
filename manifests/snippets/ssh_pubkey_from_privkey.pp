# pubkey from privkey
define sunet::snippets::ssh_pubkey_from_privkey($privkey_file=undef) {
  $_privkey_file = $privkey_file ? {
    undef   => $name,
    default => $privkey_file
  }
  exec { "ssh_pubkey_from_privkey-${_privkey_file}":
    command => "ssh-keygen -y -f ${_privkey_file} > ${_privkey_file}.pub",
    onlyif  => "test ! -s ${_privkey_file}.pub -a -s ${_privkey_file}"
  }
}
