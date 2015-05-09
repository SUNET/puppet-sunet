# Add a user to a group
define sunet::add_user_to_group($username, $group) {
  exec {"add_user_${username}_to_group_${group}_exec":
    command => "adduser --quiet $username $group",
    path    => ['/usr/local/sbin', '/usr/local/bin', '/usr/sbin', '/usr/bin', '/sbin', '/bin', ],
  }
}
