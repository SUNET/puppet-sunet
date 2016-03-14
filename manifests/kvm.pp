# Create/start a virtual machine using static IPv4 configuration
define sunet::kvm(
  $domain,
  $ip,
  $netmask,
  $resolver,
  $gateway,
  $repo,
  $tagpattern,
  $suite       = 'trusty',
  $memory      = '512',
  $rootsize    = '20G',
  $cpus        = '1',
  $extras      = [],
  ) {

  $ipv4_config = ["--domain ${domain}",
                  "--ip ${ip}",
                  "--mask ${netmask}",
                  "--gw ${gateway}",
                  "--dns ${resolver}",
                  ]

  sunet::kvm_base { $name :
    repo       => $repo,
    tagpattern => $tagpattern,
    suite      => $suite,
    memory     => $memory,
    rootsize   => $rootsize,
    cpus       => $cpus,
    extras     => flatten([$extras, $ipv4_config]),
  }

}
