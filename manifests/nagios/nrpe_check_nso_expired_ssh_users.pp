define sunet::nagios::nrpe_check_nso_expired_ssh_users ($display_name = undef) {
  sunet::nagios::nrpe_command {"check_${title}":
    command_line => '/home/ncs/ndn-ncs/bin/check_expired_ssh_users'
  }
}
