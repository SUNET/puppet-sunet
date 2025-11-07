# Setup an image in KVM
define sunet::kvm::cloudimage (
  Array[String]            $addresses       = [],
  String                   $apt_dir         = '/etc/cosmos/apt',
  Variant[String, Boolean] $apt_mirror      = 'http://se.archive.ubuntu.com/ubuntu',
  Optional[String]         $apt_proxy       = undef,
  String                   $bridge          = 'br0',
  String                   $cpus            = '1',
  String                   $description     = '',
  Boolean                  $dhcp4           = true,
  Boolean                  $dhcp6           = false,
  Boolean                  $disable_ec2     = true,  # set to false to enable fetching of metadata from 169.254.169.254
  Optional[String]         $gateway         = undef,
  Optional[String]         $gateway6        = undef,
  String                   $image_url       = 'https://cloud-images.ubuntu.com/jammy/current/jammy-server-cloudimg-amd64-disk1.img',
  String                   $images_dir      = '/var/lib/libvirt/images',
  String                   $install_options = '',  # for passing arbitrary parameters to virt-install
  String                   $local_size      = '0',
  Optional[String]         $mac             = undef,
  String                   $memory          = '1024',
  Optional[String]         $network         = undef,
  String                   $pool_name       = 'default',
  Optional[String]         $repo            = undef,
  Optional[Array]          $resolver        = undef,
  String                   $rng             = '/dev/random',
  Array[String]            $search          = [],
  Boolean                  $secure_boot     = false,
  String                   $size            = '10G',
  Optional[Array]          $ssh_keys        = undef,
  Optional[String]         $tagpattern      = undef,
  Boolean                  $use_deprecated_netplan_gw_syntax  = true,
)
{

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
      content => template('sunet/kvm/network_config-v2-ng.erb'),
      require => File[$script_dir],
      mode    => '0750',
      ;
  }

  exec { "${name}_fetch_image":
    command => "wget -O${image_src} ${image_url}",
    onlyif  => "test ! -s ${image_src}"
  }

  exec { "${name}_init":
    command => "bash ${init_script}",
    onlyif  => "test ! -f ${images_dir}/${name}.img"
  }
}
