
# inspired by http://blogs.thehumanjourney.net/oaubuntu/entry/kvm_vmbuilder_puppet_really_automated

define sunet::dhcp_kvm(
  $mac,
  $repo,
  $tagpattern,
  $suite='precise',
  $bridge='br0',
  $memory='512',
  $rootsize='20G',
  $cpus = '1',
  $iptables_input = 'INPUT',
  $iptables_output = 'OUTPUT',
  $iptables_forward = 'FORWARD',
  $extras = '',
  $tmpdir = '/var/tmp',
  $logdir = '/var/log',
  $cosmos_repo_dir = '/var/cache/cosmos/repo/',
  $images_dir = '/var/lib/libvirt/images'
  ) {

  #
  # Create
  #
  file { "${tmpdir}/firstboot_${name}":
    ensure => file,
    content => "#!/bin/sh\nuserdel -r ubuntu; cd /root && sed -i \"s/${name}.${domain}//g\" /etc/hosts && /root/bootstrap-cosmos.sh ${name} ${repo} ${tagpattern} && cosmos update && cosmos apply\n",
  } ->

  file { "${tmpdir}/files_${name}":
    ensure => file,
    content => "/root/cosmos_1.2-2_all.deb /root\n/root/bootstrap-cosmos.sh /root\n",
  } ->

  exec { "check_kvm_enabled_${name}":
    command => "/usr/sbin/kvm-ok",
  } ->

  # Make sure the host is defined in cosmos as bootstrapping will fail otherwise
  file { "${cosmos_repo_dir}/${name}":
    ensure => 'directory',
  } ->

  exec { "create_cosmos_vm_${name}":
    path          => '/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin',
    timeout       => '3600',
    environment   => ["TMPDIR=${tmpdir}",
                      ],
    command       => "virsh destroy ${name} || true ; virsh undefine ${name} || true ; /usr/bin/vmbuilder \
    kvm ubuntu -d ${images_dir}/${name} -m ${memory} --cpus ${cpus} --rootsize ${rootsize} --bridge ${bridge} \
    --hostname ${name} --ssh-key /root/.ssh/authorized_keys --suite ${suite} --flavour virtual --libvirt qemu:///system \
    --verbose --firstboot ${tmpdir}/firstboot_${name} --copy ${tmpdir}/files_${name} \
    --addpkg unattended-upgrades $extras > ${logdir}/vm-${name}-install.log 2>&1" ,
    unless => "/usr/bin/test -d ${images_dir}/${name}",
    before => File["${name}.xml"],
    require => [Package['python-vm-builder'],
                Exec["check_kvm_enabled_${name}"],
                ],
  }

  #
  # Start
  #
  file { "${name}.xml":
    ensure  => 'present',
    path    => "/etc/libvirt/qemu/${name}.xml",
  } ->

  cosmos_kvm_replace { "replace_mac_${name}":
    file                   => "/etc/libvirt/qemu/${name}.xml",
    pattern_no_slashes     => "<mac address=\\x27.+\\x27\\/>",      # \x27 is single quote in perl
    replacement_no_slashes => "<mac address=\\x27${mac}\\x27\\/>",  # \x27 is single quote in perl
  } ->

  cosmos_kvm_iptables { "fix_kvm_iptables_${name}":
    bridge          => $bridge,
    iptables_input  => $iptables_input,
    iptables_output => $iptables_output,
    iptables_forward => $iptables_forward,
  } ->

  exec { "start_cosmos_vm_${name}":
    path    => '/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin',
    timeout => '60',
    command => "virsh start ${name}",
    onlyif  => "grep -q \"<mac address='${mac}'/>\" /etc/libvirt/qemu/${name}.xml",
    unless  => "virsh list | egrep -q \\ ${name}\\ +running",
    require => [Exec["check_kvm_enabled_${name}"],
                ],
  }

  #
  # Exec virsh define IF the mac address in the XML is replaced - NOOP otherwise
  #
  exec { "virsh_define_${name}":
    path    => '/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin',
    timeout => '60',
    command => "virsh define /etc/libvirt/qemu/${name}.xml",
    refreshonly => true,
    subscribe   => Cosmos_kvm_replace["replace_mac_${name}"],
    before      => Exec["start_cosmos_vm_${name}"],
  }
}


# from http://projects.puppetlabs.com/projects/puppet/wiki/Simple_Text_Patterns/5
define cosmos_kvm_replace($file, $pattern_no_slashes, $replacement_no_slashes) {
  exec { "/usr/bin/perl -pi -e 's/$pattern_no_slashes/$replacement_no_slashes/' '$file'":
    onlyif => "/usr/bin/perl -ne 'BEGIN { \$ret = 1; } \$ret = 0 if /$pattern_no_slashes/ && ! /$replacement_no_slashes/ ; END { exit \$ret; }' '$file'",
  }
}

define cosmos_kvm_iptables(
  $bridge           = 'br0',
  $iptables_input   = 'INPUT',
  $iptables_output  = 'OUTPUT',
  $iptables_forward = 'FORWARD',
  $ipv6             = true,
  ) {

  cosmos_kvm_iptables2 { "${name}_v4":
    cmd              => 'iptables',
    bridge           => $bridge,
    iptables_input   => $iptables_input,
    iptables_output  => $iptables_output,
    iptables_forward => $iptables_forward,
  }

  if $ipv6 == true and $::operatingsystemrelease >= '13.10' {
    cosmos_kvm_iptables2 { "${name}_v6":
      cmd              => 'ip6tables',
      bridge           => $bridge,
      iptables_input   => $iptables_input,
      iptables_output  => $iptables_output,
      iptables_forward => $iptables_forward,
    }
  }
}

define cosmos_kvm_iptables2(
  $cmd,
  $bridge,
  $iptables_input,
  $iptables_output,
  $iptables_forward,
  ) {
  $chain = "cosmos-kvm-traffic"
  exec {"${name}_cmd":
    command => "${cmd} --new-chain ${chain} &&

    # if LOCAL, don't filter here
    ${cmd} -A ${chain} -m addrtype --dst-type LOCAL -j RETURN &&

    # Allow bridge interface traffic that was not LOCAL
    ${cmd} -A ${chain} -i $bridge -j ACCEPT &&

    # Allow bridge interface traffic that was not LOCAL
    ${cmd} -A ${chain} -o $bridge -j ACCEPT &&

    # Anything else, don't filter here
    ${cmd} -A ${chain} -j RETURN &&

    # Jump to this chain from input/output chains specified
    ${cmd} -I $iptables_input -j ${chain} &&
    ${cmd} -I $iptables_output -j ${chain} &&
    true",
    unless => "${cmd} -L ${chain}",
  }

  # The FORWARD chain can't deny LOCAL traffic, lest the VMs won't
  # be able to communicate with the host.
  $fwd_chain = "cosmos-kvm-traffic-forward"
  exec {"${name}_forward_cmd":
    command => "${cmd} --new-chain ${fwd_chain} &&

    # Allow bridge interface traffic
    ${cmd} -A ${fwd_chain} -i $bridge -j ACCEPT &&

    # Allow bridge interface traffic
    ${cmd} -A ${fwd_chain} -o $bridge -j ACCEPT &&

    # Anything else, don't filter here
    ${cmd} -A ${fwd_chain} -j RETURN &&

    # Jump to this chain from forward chain specified
    ${cmd} -I $iptables_forward -j ${fwd_chain} &&
    true",
    unless => "${cmd} -L ${fwd_chain}",
  }

}
