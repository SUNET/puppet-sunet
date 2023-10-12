# This puppet manifest is used to install and configure stuff
# related to grafana. The previuos generation relied on a class
# in cosmos-site.pp in nunoc-ops.

# @param servicename       The fqdn of the servicename
# @param tcpserveraddress  The version of the influx container to run
class sunet::grafana(
  String        $servicename='',
  String        $grafana_version='latest',
) {

}
