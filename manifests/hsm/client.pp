# The HSM client
class sunet::hsm::client (
  String $tarball          = '610-000397-015_SW_Linux_Luna_Client_V10.9.0_RevB.tar',
  String $baseurl      = 'https://sunet.drive.sunet.se/s/4z96YiBA2c3oFo3/download',
  String $shasum       = '8f5644e0aced01ac5718db41321d0fb6c21c5f9c80dbeda815b39cb735139e2f',
) {

  include sunet::packages::alien

  file { '/opt/hsmclient':
    ensure => directory,
  }
  file { '/opt/hsmclient/libexec':
    ensure => directory,
  }

  file { '/opt/hsmclient/libexec/download-patch-and-install':
    ensure  => 'file',
    mode    => '0755',
    owner   => 'root',
    content => file('sunet/hsm/download-patch-and-install')
  }

  exec { '/opt/hsmclient/libexec/download-patch-and-install':
    command => "/opt/hsmclient/libexec/download-patch-and-install ${tarball} ${baseurl} ${shasum}",
    creates => '/usr/safenet/lunaclient/bin/lunacm',
  }

}
