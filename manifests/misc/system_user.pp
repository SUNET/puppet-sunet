define sunet::misc::system_user(
  String           $group,
  Optional[String] $username = undef,
  Boolean          $system = true,
  Boolean          $managehome = false,
  String           $shell = '/bin/false'
) {

  $_username = $username ? {
    undef => $name,
    default => $username,
  }

  ensure_resource('group', $group, {
    ensure => present,
    name   => $group,
  })

  ensure_resource('user', $name, {
    ensure     => present,
    name       => $_username,
    membership => minimum,
    system     => $system,
    require    => Group[ $group ],
    shell      => $shell,
    managehome => $managehome,
  })
}
