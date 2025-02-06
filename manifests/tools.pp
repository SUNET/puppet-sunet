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
  $extra_tools = $facts['os']['name'] ? {
    'Ubuntu' => ['update-manager-core',
                'unattended-upgrades',
                ],
    default => []
  }

  # https://wiki.archlinux.org/title/Rng-tools
  # Note: rng-tools is not needed anymore since Kernel 5.6 because /dev/random does not block anymore.
  if versioncmp($facts['kernelmajversion'], '5.6') < 0 {
    $rng_tools = $facts['os']['name'] ? {
      'Ubuntu' => [
        'rng-tools',
      ],
      'Debian' => [
        'rng-tools5',
      ],
      default => []
    }
  } else {
    $rng_tools = []
  }

  ensure_resource(package, flatten([$debian_tools, $extra_tools, $rng_tools]), {ensure => 'installed'})
}
