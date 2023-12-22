class sunet::vc::host_environments::usb_gemalto(
   String $pkcs11_module           = "/usr/lib/libeToken.so",
  String $pkcs11_label,
  String $pkcs11_cert_label,
  String $pkcs11_key_label,
  String $pkcs11_pin                = lookup("pkcs11_pin"),
  Integer $pkcs11_slot = 0,
) {

  package { ["opensc-pkcs11", "pcscd", "pcsc-tools", "opensc"]: ensure => "latest"}

   service { 'pcscd':
    ensure  => 'running',
    enable  => true,
    require => Package['pcscd'],
  }

  sunet::remote_file { "/opt/vc/libssl1.1_1.1.0g-2ubuntu4_amd64.deb":
      remote_location => "http://archive.ubuntu.com/ubuntu/pool/main/o/openssl/libssl1.1_1.1.0g-2ubuntu4_amd64.deb",
      mode            => "0600",
    } ->
    exec {"Install libssl1.1":
        command => "dpkg -i /opt/vc/libssl1.1_1.1.0g-2ubuntu4_amd64.deb"
    }

  sunet::remote_file { "/tmp/safenetauthenticationclient-core.zip":
      remote_location => "https://www.digicert.com/StaticFiles/SAC_10_8_28_GA_Build.zip",
      mode            => "0600",
    } ->
    exec {"Unpack safenetauthenticationclient-core":
        command => "unzip  /tmp/safenetauthenticationclient-core.zip",
        unless  => "test -f /tmp/safenetauthenticationclient-core.zip",
    } ->
    exec {"Install safenetauthenticationclient-core":
        command => "apt-get install 'SAC 10.8.28 GA Build/Installation/withoutUI/Ubuntu-2004/safenetauthenticationclient-core_10.8.28_amd64.deb' -y",
        unless  => "test -f /tmp/safenetauthenticationclient-core.zip",
    }
}
