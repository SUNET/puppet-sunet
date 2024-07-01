define sunet::misc::system_user(
  String                    $group,
  Optional[String]          $username = undef,
  Boolean                   $system = true,
  Boolean                   $managehome = false,
  String                    $shell = '/bin/false',
  Enum['present', 'absent'] $ensure = 'present',
  Optional[String]          $home = undef,
  Optional[Integer]         $uid = undef,
  Optional[Integer]         $gid = undef,
  Optional[Array[String]]   $groups = undef,
) {

  $_username = $username ? {
    undef => $name,
    default => $username,
  }

  ensure_resource('group', $group, {
    ensure => $ensure,
    name   => $group,
    gid    => $gid,
  })

  ensure_resource('user', $name, {
    ensure     => $ensure,
    name       => $_username,
    membership => 'minimum',
    system     => $system,
    require    => Group[ $group ],
    shell      => $shell,
    managehome => $managehome,
    home       => $home,
    uid        => $uid,
    gid        => $group,
    groups     => $groups,
  })
}
