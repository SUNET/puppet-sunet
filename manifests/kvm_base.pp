# Create/start a KVM virtual machine
# inspired by http://blogs.thehumanjourney.net/oaubuntu/entry/kvm_vmbuilder_puppet_really_automated
define sunet::kvm_base(
  $repo,
  $tagpattern,
  $mac                = undef,
  $suite              = 'trusty',
  $bridge             = 'br0',
  $memory             = '512',
  $rootsize           = '20G',
  $cpus               = '1',
  $iptables_input     = 'INPUT',
  $iptables_output    = 'OUTPUT',
  $iptables_forward   = 'FORWARD',
  $extras             = [],
  $tmpdir             = '/var/tmp',
  $logdir             = '/var/log',
  $cosmos_repo_dir    = '/var/cache/cosmos/repo/',
  $images_dir         = '/var/lib/libvirt/images',
  $firstboot_template = 'sunet/kvm/firstboot.erb',
  $copy_files         = ['/root/cosmos_1.2-2_all.deb /root',
                        '/root/bootstrap-cosmos.sh /root',
                        ],
  $vmbuilder_args     = undef,   # use default set defined below, to allow use of variables
  ) {

  #
  # Create firstboot script
  #
  file { "${tmpdir}/firstboot_${name}":
    ensure  => file,
    mode    => '0600',
    content => template($firstboot_template),  # not _content but _template to get $name etc. right in templates
  } ->

  file { "${tmpdir}/files_${name}":
    ensure  => file,
    mode    => '0600',
    content => join(flatten([$copy_files, '']), "\n"),  # add '' to get a line feed at EOF
  } ->

  # Make sure the host is defined in cosmos as bootstrapping will fail otherwise
  file { "${cosmos_repo_dir}/${name}":
    ensure => 'directory',
  }

  # Verify that virtualization technology is available (enabled in BIOS) on the host
  exec { "check_kvm_enabled_${name}":
    command => '/usr/sbin/kvm-ok',
  }

  $_default_vmbuilder_args = ['kvm ubuntu',
                              "--suite ${suite}",
                              "-d ${images_dir}/${name}",
                              "-m ${memory}",
                              "--cpus ${cpus}",
                              "--rootsize ${rootsize}",
                              "--bridge ${bridge}",
                              "--hostname ${name}",
                              '--ssh-key /root/.ssh/authorized_keys',
                              '--flavour virtual',
                              '--libvirt qemu:///system',
                              '--verbose',
                              "--firstboot ${tmpdir}/firstboot_${name}",
                              "--copy ${tmpdir}/files_${name}",
                              '--addpkg unattended-upgrades',
                              '--tmpfs -',
                              ]

  # Use supplied $vmbuilder_args, or if it is undef use $_default_vmbuilder_args.
  # Add $extras which, thanks to flatten() below, can be either a list of strings or a string.
  $_all_vmbuilder_args = [pick($vmbuilder_args, $_default_vmbuilder_args),
                          $extras,
                          ]
  $_vmbuilder_args = join(flatten($_all_vmbuilder_args), ' ')

  ensure_resource('package','python-vm-builder',{ensure => latest})

  exec { "create_sunet_vm_${name}":
    path        => '/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin',
    timeout     => '3600',
    environment => ["TMPDIR=${tmpdir}",
                      ],
    command     => "virsh destroy ${name} || true ; virsh undefine ${name} || true ; \
    /usr/bin/vmbuilder ${_vmbuilder_args} > ${logdir}/vm-${name}-install.log 2>&1" ,
    unless      => "/usr/bin/test -d ${images_dir}/${name}",
    before      => Augeas["configure_domain_${name}"],
    require     => [Package['python-vm-builder'],
                    Exec["check_kvm_enabled_${name}"],
                    File["${cosmos_repo_dir}/${name}"],
                    ],
  } ->

  sunet::kvm_base::configure_mac_address { $name:
    mac => $mac,
  } ->

  #
  # Start the virtual machine
  #
  sunet::kvm_base::start_vm { $name: }
}

# Update the MAC address in the qemu XML file
define sunet::kvm_base::configure_mac_address(
  $mac = undef,
) {
  include augeas

  $_augeas_update_mac = $mac ? {
    undef   => [],
    default => "set domain/devices/interface/mac/#attribute/address '${mac}'",
  }

  $_augeas_changes = flatten([$_augeas_update_mac])

  file { "/etc/libvirt/qemu/${name}.xml":
    ensure    => 'present',
  } ->

  augeas{ "configure_domain_${name}":
    incl    => "/etc/libvirt/qemu/${name}.xml",
    lens    => 'Xml.lns',
    context => "/files/etc/libvirt/qemu/${name}.xml",
    changes => $_augeas_changes,
    notify  => Exec["virsh_define_${name}"],  # Poke the refreshonly exec that will call virsh define
  }

  #
  # Exec virsh define IF the mac address in the XML is replaced - NOOP otherwise
  #
  exec { "virsh_define_${name}":
    path        => '/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin',
    timeout     => '60',
    command     => "virsh define /etc/libvirt/qemu/${name}.xml",
    refreshonly => true,
    subscribe   => Augeas["configure_domain_${name}"],
    before      => Exec["sunet_start_vm_kvm_${name}"],
  }
}

# Start a VM
define sunet::kvm_base::start_vm() {

  # Ensure the firewall is set up to allow traffic to/from the guest(s)
  sunet_kvm_iptables { "fix_kvm_iptables_${name}":
    bridge           => $bridge,
    iptables_input   => $iptables_input,
    iptables_output  => $iptables_output,
    iptables_forward => $iptables_forward,
  } ->

  # Make sure the virtual machine is started
  exec { "sunet_start_vm_kvm_${name}":
    path    => '/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin',
    timeout => '60',
    command => "virsh start ${name}",
    unless  => "virsh list | egrep -q \\ ${name}\\ +running",
    require => [Sunet_kvm_iptables["fix_kvm_iptables_${name}"],
                ],
  }

}

# Configure iptables to allow forwarding of traffic to/from guests
define sunet_kvm_iptables(
  $bridge           = 'br0',
  $iptables_input   = 'INPUT',
  $iptables_output  = 'OUTPUT',
  $iptables_forward = 'FORWARD',
  $ipv6             = true,
  ) {

  sunet_kvm_iptables2 { "${name}_v4":
    cmd              => 'iptables',
    bridge           => $bridge,
    iptables_input   => $iptables_input,
    iptables_output  => $iptables_output,
    iptables_forward => $iptables_forward,
  }

  if $ipv6 == true and $::operatingsystemrelease >= '13.10' {
    sunet_kvm_iptables2 { "${name}_v6":
      cmd              => 'ip6tables',
      bridge           => $bridge,
      iptables_input   => $iptables_input,
      iptables_output  => $iptables_output,
      iptables_forward => $iptables_forward,
    }
  }
}

define sunet_kvm_iptables2(
  $cmd,
  $bridge           = 'br0',
  $iptables_input   = 'INPUT',
  $iptables_output  = 'OUTPUT',
  $iptables_forward = 'FORWARD',
  ) {
  $chain = 'sunet-kvm-traffic'
  exec {"${name}_cmd":
    command => "${cmd} --new-chain ${chain} &&

    # if LOCAL, don't filter here
    ${cmd} -A ${chain} -m addrtype --dst-type LOCAL -j RETURN &&

    # Allow bridge interface traffic that was not LOCAL
    ${cmd} -A ${chain} -i ${bridge} -j ACCEPT &&

    # Allow bridge interface traffic that was not LOCAL
    ${cmd} -A ${chain} -o ${bridge} -j ACCEPT &&

    # Anything else, don't filter here
    ${cmd} -A ${chain} -j RETURN &&

    # Jump to this chain from input/output chains specified
    ${cmd} -I ${iptables_input} -j ${chain} &&
    ${cmd} -I ${iptables_output} -j ${chain} &&
    true",
    unless  => "${cmd} -L ${chain}",
  }

  # The FORWARD chain can't deny LOCAL traffic, lest the VMs won't
  # be able to communicate with the host.
  $fwd_chain = 'sunet-kvm-traffic-forward'
  exec {"${name}_forward_cmd":
    command => "${cmd} --new-chain ${fwd_chain} &&

    # Allow bridge interface traffic
    ${cmd} -A ${fwd_chain} -i ${bridge} -j ACCEPT &&

    # Allow bridge interface traffic
    ${cmd} -A ${fwd_chain} -o ${bridge} -j ACCEPT &&

    # Anything else, don't filter here
    ${cmd} -A ${fwd_chain} -j RETURN &&

    # Jump to this chain from forward chain specified
    ${cmd} -I ${iptables_forward} -j ${fwd_chain} &&
    true",
    unless  => "${cmd} -L ${fwd_chain}",
  }

}
