class sunet::ipam::create_cli_user {

  require sunet::ipam::main

  # The hash containing local user information who can use nipap cli.
  $cli_users = hiera_hash('ipam_cli_users')

  # Creation of local user accounts to use nipap cli.
  create_resources ('sunet::ipam::cli_user', $cli_users)
}
