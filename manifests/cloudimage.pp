include stdlib

define sunet::cloudimage (
  String           $image_url   = "https://cloud-images.ubuntu.com/trusty/current/trusty-server-cloudimg-amd64-disk1.img",
  Boolean          $dhcp        = true,
  Optional[String] $mac         = undef,
  String           $size        = '10G',
  String           $bridge      = 'br0',
  String           $memory      = '1024',
  String           $cpus        = '1',
  Optional[Array]  $resolver    = undef,
  Array[String]    $search      = [],
  Optional[String] $ip          = undef,
  Optional[String] $netmask     = undef,
  Optional[String] $gateway     = undef,
  Optional[String] $ip6         = undef,
  String           $netmask6    = '64',
  Optional[String] $gateway6    = undef,
  Optional[String] $tagpattern  = undef,
  Optional[String] $repo        = undef,
  Optional[Array]  $ssh_keys    = undef,
  String           $description = '',
  String           $apt_dir     = '/etc/cosmos/apt',
  Optional[String] $apt_proxy   = undef,
  String           $images_dir  = '/var/lib/libvirt/images',
  String           $pool_name   = 'default',
  String           $local_size  = '0',
  String           $rng         = '/dev/random',
  Boolean          $disable_ec2 = false,  # set to true to disable fetching of metadata from 169.254.169.254
  String           $network_ver = '1',
  # Parameters for networkv_ver 2
  Array[String]    $addresses   = [],
  Boolean          $dhcp4       = true,
  Boolean          $dhcp6       = false,
)
{
  if $::operatingsystem == 'Ubuntu' and versioncmp($::operatingsystemrelease, '16.04') >= 0 {
    $kvm_package = 'qemu-kvm'
  } else {
    $kvm_package = 'kvm'  # old name
  }
  ensure_resource('package', ['cpu-checker',
                              'mtools',
                              'dosfstools',
                              $kvm_package,
                              'libvirt-bin',
                              'virtinst',
                              ], {ensure => 'installed'})

  $image_url_a = split($image_url, "/")
  $image_name = $image_url_a[-1]
  $image_src = "${images_dir}/${image_name}"
  $script_dir = "${images_dir}/../sunet-files"
  $init_script = "${script_dir}/${name}/${name}-init.sh"
  $meta_data = "${script_dir}/${name}/${name}_meta-data"
  $user_data = "${script_dir}/${name}/${name}_user-data"
  $network_config = "${script_dir}/${name}/${name}_network-config"

  ensure_resource('file', $script_dir, {
    ensure => 'directory',
    mode   => '0755',
  })

  $network_template = $network_ver ? {
    '1' => 'sunet/cloudimage/network_config.erb',
    '2' => 'sunet/cloudimage/network_config-v2.erb',
  }
  file {
    "${script_dir}/${name}":
      ensure => 'directory',
      mode   => '0755',
      ;
    $init_script:
      content => template("sunet/cloudimage/mk_cloud_image.erb"),
      require => File[$script_dir],
      mode    => "0750",
      ;
    $meta_data:
      content => template("sunet/cloudimage/meta_data.erb"),
      require => File[$script_dir],
      mode    => "0750",
      ;
    $user_data:
      content => template("sunet/cloudimage/user_data.erb"),
      require => File[$script_dir],
      mode    => "0750",
      ;
    $network_config:
      content => template($network_template),
      require => File[$script_dir],
      mode    => "0750",
      ;
  } ->

  exec { "${name}_fetch_image":
     command => "wget -O${image_src} ${image_url}",
     onlyif  => "test ! -s ${image_src}"
  } ->

  exec { "${name}_init":
     command => "bash $init_script",
     onlyif  => "test ! -f ${images_dir}/${name}.img"
  }
}
