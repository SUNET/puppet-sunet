class sunet::vc::host_environments::softhsm2(
  String $pkcs11_module           = '/usr/lib/softhsm/libsofthsm2.so',
  String $pkcs11_label,
  String $pkcs11_cert_label,
  String $pkcs11_key_label,
  String $pkcs11_pin,
  Integer $pkcs11_slot = 0,
) {

  package { ["softhsm2", "opensc-pkcs11", "pcscd"]: ensure => "latest"}

  file { '/opt/vc/softhsm2-post_install.sh':
    ensure => file,
    mode   => '0600',
    owner  => 'root',
    group  => 'root',
    content => template("sunet/vc/pkcs11_environments/softhsm2-post_install.sh.erb")
  }

  exec {"Run softhsm2-post_install script":
        command => "/usr/bin/bash ./softhsm2-post_install.sh",
        cwd => "./opt/vc/",
        #unless  => "test -f /tmp/safenetauthenticationclient-core.zip",
    }

  service { 'pcscd':
    ensure  => 'running',
    enable  => true,
    require => Package['pcscd'],
  }
}

