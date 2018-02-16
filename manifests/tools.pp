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
  $extra_tools = $::operatingsystem ? {
    'Ubuntu' => ['update-manager-core',
                 'unattended-upgrades',
                 ],
    false => []
  }
  ensure_resource(package, flatten([$debian_tools, $extra_tools]), {ensure => 'installed'})
}
