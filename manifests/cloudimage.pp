define sunet::cloudimage (
  $image_url   = "https://cloud-images.ubuntu.com/trusty/current/trusty-server-cloudimg-amd64-disk1.img",
  $dhcp        = true,
  $size        = "1G",
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
  $ssh_keys    = undef
)
{
  $image_url_a = split($image_url,"/")
  $image_name = $image_url_a[-1]
  $image_src = "/var/lib/libvirt/images/${image_name}"
  package {'cpu-checker': ensure => latest } ->
  package {'mtools': ensure => latest } ->
  package {'libvirt-bin': ensure => latest } ->
  package {'uuid-runtime': ensure => latest } ->
  package {'virtinst': ensure => latest } ->
  file { "/var/lib/libvirt/images/${name}": ensure => directory } ->
  exec {"wget -O${image_src} ${image_url}":
     onlyif => "test ! -f ${image_src}"
  }
  file { "/var/lib/libvirt/images/${name}/${name}-init.sh":
     content => template("sunet/cloudimage/mk_cloud_image.erb"),
     mode    => "0755"
  } -> 
  exec { "/var/lib/libvirt/images/${name}/${name}-init.sh":
     onlyif => "test ! -f /var/lib/libvirt/images/${name}/${name}.img"
  }
}
