# Create/start a virtual machine using DHCP for IPv4 configuration
define sunet::dhcp_kvm(
  $mac,
  $repo,
  $tagpattern,
  $suite       = 'precise',
  $memory      = '512',
  $rootsize    = '20G',
  $cpus        = '1',
  $extras      = [],
  ) {

  sunet::kvm_base { $name :
    mac        => $mac,
    repo       => $repo,
    tagpattern => $tagpattern,
    suite      => $suite,
    memory     => $memory,
    rootsize   => $rootsize,
    cpus       => $cpus,
    extras     => $extras,
  }

}
