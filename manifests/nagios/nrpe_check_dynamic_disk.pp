# Check disk
define sunet::nagios::nrpe_check_dynamic_disk (
  String $inode_critical = '5%',
  String $inode_warning = '15%',
  String $space_critical = '5%',
  String $space_warning = '15%',
) {

    sunet::nagios::nrpe_command {'check_dynamic_disk':
    command_line => "/usr/lib/nagios/plugins/check_disk -w ${space_warning} -c ${space_critical} -W ${inode_warning} -K ${inode_critical} -X overlay -X aufs -X tmpfs -X devtmpfs -X nsfs -A -i '^/var/lib/docker/plugins/.*/propagated-mount|^/snap|^/var/snap|^/sys/kernel/debug/tracing'"
  }
}
