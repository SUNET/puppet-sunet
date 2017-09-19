class sunet::kvmtools {
   ensure_resource('package',['cpu-checker','mtools','dosfstools','kvm','libvirt-bin','virtinst'],{ensure => 'latest'})
}
