# Deprecated, use sunet::misc::system_user.
define sunet::system_user(
  $username,
  $group,
  $system = true,
  $shell = '/bin/false'
  ) {

  user { $username :
    ensure => present,
    name => $username,
    membership => minimum,
    system => $system,
    require => Group[ $group ],
    shell => $shell,
  }

  group { $group :
    ensure => present,
    name => $group,
  }

}
