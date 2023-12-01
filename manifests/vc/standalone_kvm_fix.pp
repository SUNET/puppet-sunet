class sunet::vc::standalone_kvm_fix(
  String  $vc_version="latest",
  String  $mongodb_version="4.0.10",
  String  $mockca_sleep="20",
  String  $interface="ens3",
  String  $ca_token="dummy",
) {


  file { '/root/.ssh/authorized_keys':
    ensure => file,
    mode   => '0600',
    owner  => 'root',
    group  => 'root',
    content => template("sunet/vc/standalone/kvm_ssh_authorized_keys")
   }

  # sunet::ssh_keys { 'vcops':
  #   config => lookup('vcops_ssh_config', undef, undef, {}),
  # }

  # sunet::misc::system_user { 'sunet':
  #   username   => 'sunet',
  #   group      => 'sunet',
  #   shell      => '/bin/false',
  #   managehome => false
  # }

  # file { '/var/log/sunet':
  #   ensure => directory,
  #   mode    => '0770',
  #   group   => 'sunet',
  #   require =>  [ Group['sunet'] ],
  # }

}
