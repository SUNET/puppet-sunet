include stdlib

define sunet::cloudimage (
  $image_url   = "https://cloud-images.ubuntu.com/trusty/current/trusty-server-cloudimg-amd64-disk1.img",
  $dhcp        = true,
  $mac         = undef,
  $size        = "10G",
  $bridge      = "br0",
  $memory      = "1024",
  $cpus        = "1",
  $resolver    = undef,
  $ip          = undef,
  $netmask     = undef,
  $gateway     = undef,
  $ip6         = undef,
  $netmask6    = "64",
  $gateway6    = undef,
  $tagpattern  = undef,
  $repo        = undef,
  $ssh_keys    = undef,
  $description = '',
  $apt_dir     = '/etc/cosmos/apt',
  $images_dir  = '/var/lib/libvirt/images',
  $pool_name   = 'default',
  $local_size  = '0',
)
{
  ensure_resource('package', ['cpu-checker',
                              'mtools',
                              'kvm',
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
      content => template("sunet/cloudimage/network_config.erb"),
      require => File[$script_dir],
      mode    => "0750",
      ;
  } ->

  exec { "${name}_fetch_image":
     command => "wget -O${image_src} ${image_url}",
     onlyif  => "test ! -s ${image_src}"
  } ->

  exec { "${name}_init":
     command => $init_script,
     onlyif  => "test ! -f ${images_dir}/${name}.img"
  }
}
