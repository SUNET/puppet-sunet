# This manifest is managed using cosmos

class sunet::tools {
   $tools = ["vim","traceroute","tcpdump","molly-guard","less","rsync","screen","strace","lsof","update-manager-core","unattended-upgrades"]
   package { $tools: ensure => latest}
}
