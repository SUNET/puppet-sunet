include stdlib

# cloudimage
define sunet::cloudimage (
  String                   $image_url   = 'https://cloud-images.ubuntu.com/trusty/current/trusty-server-cloudimg-amd64-disk1.img',
  Boolean                  $dhcp        = true,
  Optional[String]         $network     = undef,
  Optional[String]         $mac         = undef,
  String                   $size        = '10G',
  String                   $bridge      = 'br0',
  String                   $memory      = '1024',
  String                   $cpus        = '1',
  Optional[Array]          $resolver    = undef,
  Array[String]            $search      = [],
  Optional[String]         $ip          = undef,
  Optional[String]         $netmask     = undef,
  Optional[String]         $gateway     = undef,
  Optional[String]         $ip6         = undef,
  String                   $netmask6    = '64',
  Optional[String]         $gateway6    = undef,
  Optional[String]         $tagpattern  = undef,
  Optional[String]         $repo        = undef,
  Optional[Array]          $ssh_keys    = undef,
  String                   $description = '',
  String                   $apt_dir     = '/etc/cosmos/apt',
  Optional[String]         $apt_proxy   = undef,
  String                   $images_dir  = '/var/lib/libvirt/images',
  String                   $pool_name   = 'default',
  String                   $local_size  = '0',
  String                   $rng         = '/dev/random',
  Boolean                  $disable_ec2 = true,  # set to false to enable fetching of metadata from 169.254.169.254
  String                   $network_ver = '1',
  # Parameters for         network_ver 2
  Array[String]            $addresses   = [],
  Boolean                  $dhcp4       = true,
  Boolean                  $dhcp6       = false,
  String                   $install_options = '',  # for passing arbitrary parameters to virt-install
  Boolean                  $secure_boot = false,
  Variant[String, Boolean] $apt_mirror  = 'http://se.archive.ubuntu.com/ubuntu',
)
{
  warning ('sunet::cloudimage is deprecated - please migrate to sunet::kvm::host and sunet::kvm::cloudimage')
  if $facts['os']['name'] == 'Ubuntu' and versioncmp($facts['os']['release']['full'], '22.04') >= 0 {
    $kvm_package = 'qemu-system-x86'
  } elsif $facts['os']['name'] == 'Ubuntu' and versioncmp($facts['os']['release']['full'], '16.04') >= 0 {
    $kvm_package = 'qemu-kvm'
  } else {
    $kvm_package = 'kvm'  # old name
  }
  if $facts['os']['name'] == 'Ubuntu' and versioncmp($facts['os']['release']['full'], '18.04') >= 0 {
    # Manages CPU affinity for virtual CPUs. Seems to be required on new KVM hosts in eduid,
    # to keep the VMs from crashing.
    $numad_package = 'numad'
  } else {
    $numad_package = []
  }
  if $facts['os']['name'] == 'Ubuntu' and versioncmp($facts['os']['release']['full'], '19.10') >= 0 {
    $libvirt_package = 'libvirt-daemon-system'
  } else {
    $libvirt_package = 'libvirt-bin'
  }
  if $facts['os']['name'] == 'Ubuntu' and versioncmp($facts['os']['release']['full'], '22.04') >= 0 {
    # virsh command has been broken out of the libvirt-package for Jammy
    $virt_extra = 'libvirt-clients'
  } else {
    $virt_extra = []
  }
  ensure_resource('package', flatten(['cpu-checker',
                                      'mtools',
                                      'dosfstools',
                                      $kvm_package,
                                      $libvirt_package,
                                      $virt_extra,
                                      'virtinst',
                                      'ovmf',  # for UEFI booting virtual machines
                                      $numad_package,
                                      ]), {ensure => 'installed'})

  $image_url_a = split($image_url, '/')
  $image_name = $image_url_a[-1]
  $image_src = "${images_dir}/${image_name}"
  $script_dir = "${images_dir}/../sunet-files"
  $init_script = "${script_dir}/${name}/${name}-init.sh"
  $meta_data = "${script_dir}/${name}/${name}_meta-data"
  $user_data = "${script_dir}/${name}/${name}_user-data"
  $network_config = "${script_dir}/${name}/${name}_network-config"

  if $secure_boot {
    if str2bool($facts['sunet_kvmhost_can_secureboot']) {
      $sb_args = '--boot=uefi,loader_secure=yes,loader=/usr/share/OVMF/OVMF_CODE.secboot.fd,nvram_template=/usr/share/OVMF/OVMF_VARS.ms.fd --machine=q35 --features smm=on'
    } else {
      # The ovmf package in Ubuntu 18.04 did not include the boot loader and NVRAM content to
      # do secure boot. It needs to be installed from a newer distribution.
      #
      # XXX an alternative here would be to set sb_args to just '--boot=uefi,loader_secure=yes'
      # which would make it possible to install VMs and _then_ install the secure boot loader
      # (and virsh editing all the already installed VMs).
      fail("Secure boot of VM ${name} was requested, but it seems the `ovmf' package on this host is too old")
    }
  }

  ensure_resource('file', $script_dir, {
    ensure => 'directory',
    mode   => '0755',
  })

  $network_template = $network_ver ? {
    '1' => 'sunet/cloudimage/network_config.erb',
    '2' => 'sunet/kvm/network_config-v2.erb',
  }
  file {
    "${script_dir}/${name}":
      ensure => 'directory',
      mode   => '0755',
      ;
    $init_script:
      content => template('sunet/kvm/mk_cloud_image.erb'),
      require => File[$script_dir],
      mode    => '0750',
      ;
    $meta_data:
      content => template('sunet/kvm/meta_data.erb'),
      require => File[$script_dir],
      mode    => '0750',
      ;
    $user_data:
      content => template('sunet/kvm/user_data.erb'),
      require => File[$script_dir],
      mode    => '0750',
      ;
    $network_config:
      content => template($network_template),
      require => File[$script_dir],
      mode    => '0750',
      ;
  }

  -> exec { "${name}_fetch_image":
    command => "wget -O${image_src} ${image_url}",
    onlyif  => "test ! -s ${image_src}"
  }

  -> exec { "${name}_init":
    command => "bash ${init_script}",
    onlyif  => "test ! -f ${images_dir}/${name}.img"
  }
}
