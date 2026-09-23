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

  # molly-guard diverts /usr/sbin/reboot to a shell script. From Ubuntu 26.04
  # the initramfs is built with dracut, which copies the symlink but not the
  # script, so on hosts with complex storage (md RAID, LVM, multipath,
  # dm-crypt) the shutdown initramfs cannot reboot the host and strands it in
  # a debug shell (Debian #992351). Included here, next to the package that
  # causes it, so the workaround is available wherever molly-guard is - but it
  # is opt-in and does nothing unless enabled per host or group in Hiera:
  #   sunet::dracut::no_shutdown_initramfs::enable: true
  include sunet::dracut::no_shutdown_initramfs

  ensure_resource(package, flatten([$debian_tools, $extra_tools, $rng_tools]), {ensure => 'installed'})
}
