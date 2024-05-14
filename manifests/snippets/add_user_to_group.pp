# Add a user to a group
define sunet::snippets::add_user_to_group($username, $group) {
  ensure_resource('exec', "add_user_${username}_to_group_${group}_exec", {
    command => "adduser --quiet $username $group",
    path    => ['/usr/sbin', '/usr/bin', '/sbin', '/bin', ],
  })
}
