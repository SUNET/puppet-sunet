# Install baseline of tools
class sunet::tools {
  $debian_tools = ['vim',
                   'traceroute',
                   'tcpdump',
                   'molly-guard',
                   'less',
                   'rsync',
                   'screen',
                   'strace',
                   'lsof',
                   ]
  $ubuntu_tools = $::operatingsystem == 'Ubuntu' ? {
    true => ['update-manager-core',
             'unattended-upgrades',
             ],
    false => []
  }
  ensure_resource(package, flatten([$debian_tools, $ubuntu_tools]), {ensure => 'installed'})
}
