class sunet::kvmtools {
   package {'cpu-checker': ensure => latest } ->
   package {'mtools': ensure => latest } ->
   package {'kvm': ensure => latest } ->
   package {'libvirt-bin': ensure => latest } ->
   package {'virtinst': ensure => latest }
}
