# Create directory owned by user root. Default mode 0755.
define sunet::misc::create_root_dir(
  $group = 'root',
  $mode  = '0755',
) {
  eduid::misc::create_dir { $name :
    owner => 'root',
    group => $group,
    mode  => $mode,
  }
}
