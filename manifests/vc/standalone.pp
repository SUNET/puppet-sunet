class sunet::vc::standalone(
  String  $vc_version="latest",
  String  $mongodb_version="4.0.10",
  String  $mockca_sleep="20",
  Boolean $production="false",
  #hash with basic_auth key/value
) {

  file { '/opt/vc':
    ensure  => directory,
    mode    =>  '0755',
    owner   =>  'root',
    group   =>  'root',
  }
}
