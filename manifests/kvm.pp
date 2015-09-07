
# inspired by http://blogs.thehumanjourney.net/oaubuntu/entry/kvm_vmbuilder_puppet_really_automated

define sunet::kvm(
  $domain,
  $ip,
  $netmask,
  $resolver,
  $gateway,
  $repo,
  $tagpattern,
  $suite='precise',
  $bridge='br0',
  $memory='512',
  $rootsize='20G',
  $cpus = '1',
  $extras = '',
  $tmpdir = '/var/tmp',
  $logdir = '/var/log',
  $cosmos_repo_dir = '/var/cache/cosmos/repo/',
  $images_dir = '/var/lib/libvirt/images'
  ) {

  file { "${tmpdir}/firstboot_${name}":
     ensure => file,
     content => "#!/bin/sh\nuserdel -r ubuntu; cd /root && sed -i \"s/${name}.${domain}//g\" /etc/hosts && /root/bootstrap-cosmos.sh ${name} ${repo} ${tagpattern} && cosmos update ; cosmos apply\n"
  } ->

  file { "${tmpdir}/files_${name}":
     ensure => file,
     content => "/root/cosmos_1.2-2_all.deb /root\n/root/bootstrap-cosmos.sh /root\n"
  } ->

  exec { "check_kvm_enabled_${name}":
    command => "/usr/sbin/kvm-ok",
  } ->

  # Make sure the host is defined in cosmos as bootstrapping will fail otherwise
  file { "/var/cache/cosmos/repo/${name}":
    ensure => 'directory',
  } ->

  exec { "create_cosmos_vm_${name}":
    path          => '/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin',
    timeout       => 3600,
    environment   => ["TMPDIR=${tmpdir}",
                      ],
    command       => "virsh destroy ${name} || true ; virsh undefine ${name} || true ; /usr/bin/vmbuilder \
      kvm ubuntu  -d ${images_dir}/${name} -m $memory --cpus ${cpus} --rootsize ${rootsize} \
      --domain ${domain} --bridge ${bridge} --ip ${ip} --mask ${netmask} --gw ${gateway} --dns ${resolver} \
      --hostname ${name} --ssh-key /root/.ssh/authorized_keys --suite ${suite} --flavour virtual --libvirt qemu:///system \
      --verbose --firstboot ${tmpdir}/firstboot_${name} --copy ${tmpdir}/files_${name} \
      --addpkg unattended-upgrades $extras > ${logdir}/vm-${name}-install.log 2>&1 && virsh start ${name}" ,
    unless        => "/usr/bin/test -d ${images_dir}/${name}",
    require       => [Package['python-vm-builder']]
  }

}
