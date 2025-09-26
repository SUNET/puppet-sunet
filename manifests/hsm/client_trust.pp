# The HSM client trust  fabric
define sunet::hsm::client_trust (
  Array   $hsm_servers,
  String  $mode = '0750',
  String  $owner = 'root',
) {

  file { '/usr/safenet/lunaclient/cert/server/':
    ensure => 'directory',
    mode   => $mode,
  }

  concat { '/usr/safenet/lunaclient/cert/server/CAFile.pem':
    owner          => $owner,
    ensure_newline => true,
    mode           => $mode,
  }


  $hsm_servers.each  | $hsm | {

    file { "/usr/safenet/lunaclient/cert/server/${hsm}Cert.pem":
      ensure  => 'file',
      mode    => $mode,
      owner   => $owner,
      content => file("sunet/hsm/servers/${hsm}Cert.pem")
    }

     concat::fragment { $hsm:
      target  => '/usr/safenet/lunaclient/cert/server/CAFile.pem',
      content => file("sunet/hsm/servers/${hsm}Cert.pem")
    }

  }
}
