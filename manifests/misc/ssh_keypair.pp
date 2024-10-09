# ssh_keypair
define sunet::misc::ssh_keypair(
  String $public,
  String $private,
  String $user = 'root',
  Enum['present', 'absent'] $ensure = 'present',
) {
  file {
    $name:
      owner   => $user,
      mode    => '0400',
      content => $private,
      ;
    "${name}.pub":
      owner   => $user,
      mode    => '0400',
      content => $public,
      ;
  }
}
