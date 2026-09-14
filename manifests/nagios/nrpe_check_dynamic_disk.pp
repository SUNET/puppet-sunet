# Check disk
define sunet::nagios::nrpe_check_dynamic_disk (
  String $inode_critical = '5%',
  String $inode_warning = '15%',
  String $space_critical = '5%',
  String $space_warning = '15%',
) {

  $_space_warning = lookup('check_space_warning', undef, undef, $space_warning)
  $_space_critical = lookup('check_space_critical', undef, undef, $space_critical)

    sunet::nagios::nrpe_command {'check_dynamic_disk':
    command_line => "/usr/lib/nagios/plugins/check_disk -w ${_space_warning} -c ${_space_critical} -W ${inode_warning} -K ${inode_critical} -X overlay -X aufs -X tmpfs -X devtmpfs -X nsfs -A -i '^/var/lib/docker/plugins/.*/propagated-mount|^/snap|^/var/snap|^/sys/kernel/debug/tracing'"
  }
}
