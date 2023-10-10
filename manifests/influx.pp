# This puppet manifest is used to install and configure stuff
# related to influxdb. The previuos generation relied on server
# specific configuration specified in cosmos-site.pp in nunoc-ops.

# @param nodename          The nodename registered in the IBM system for this server
# @param tcpserveraddress  The address of the TSM server we are sending backup data to
# @param monitor_backups   If we should monitor scheduled backups
# @param version           The version of the client to install
# @param backup_dirs       Specific directories to backup, default is to backup everything
class sunet::influx(
  String        $servername='',
) {

/*

*/
}
