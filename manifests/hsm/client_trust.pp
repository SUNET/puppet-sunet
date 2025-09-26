# The HSM client trust  fabric
class sunet::hsm::client_trust (
  Array   $hsm_servers,
  String  $mode = '0750',
  String  $owner = 'root',
) {

  file { '/usr/safenet/lunaclient/cert/server/':
    ensure => 'directory',
    mode   => $mode,
  }

  $hsm_servers.each  | $hsm | {

    file { "/usr/safenet/lunaclient/cert/server/${hsm}Cert.pem":
      ensure  => 'file',
      mode    => $mode,
      owner   => $owner,
      content => file("sunet/hsm/servers/${hsm}Cert.pem")
    }
  }
}
