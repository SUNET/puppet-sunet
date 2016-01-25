class sunet::kvmtools {
   ensure_resource('package',['cpu-checker','mtools','kvm','libvirt-bin','virtinst'],{ensure => 'latest'})
}
