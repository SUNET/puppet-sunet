# needrestart checks which daemons need to be restarted after library upgrades.
define sunet::nagios::nrpe_check_needrestart (
) {
    sunet::sudoer {'nagios_run_needrestart_command':
        user_name    => 'nagios',
        collection   => 'nagios',
        command_line => '/usr/sbin/needrestart -p -l'
    }
    sunet::nagios::nrpe_command {'check_needrestart':
        command_line => 'sudo /usr/sbin/needrestart -p -l'
    }
}
