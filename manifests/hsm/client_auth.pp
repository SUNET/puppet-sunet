# The HSM client
define sunet::hsm::client_auth (
  String $mode = '0750',
) {

  file { '/usr/safenet/lunaclient/cert/client/':
    ensure => 'directory',
    mode   => $mode,
  }

  $me = $facts['networking']['fqdn']
  sunet::snippets::keygen {$me:
    key_file  => "/usr/safenet/lunaclient/cert/client/${me}Key.pem",
    cert_file => "/usr/safenet/lunaclient/cert/client/${me}.pem"
  }
}
