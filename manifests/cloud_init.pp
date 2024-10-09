# Reconfigure cloud init
class sunet::cloud_init {
  exec { 'update-cloud-init':
      command     => 'dpkg-reconfigure -f noninteractive cloud-init',
      refreshonly => true
  }
}
