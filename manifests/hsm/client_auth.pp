# The HSM client
define sunet::hsm::client_auth (
  String $mode = '0750',
) {
  file { '/usr/safenet/':
    ensure => 'directory',
    mode   => $mode,
  }
  file { '/usr/safenet/lunaclient/':
    ensure  => 'directory',
    mode    => $mode,
    require => File['/usr/safenet/'],
  }
  file { '/usr/safenet/lunaclient/cert/':
    ensure  => 'directory',
    mode    => $mode,
    require => File['/usr/safenet/lunaclient/'],
  }
  file { '/usr/safenet/lunaclient/cert/client/':
    ensure  => 'directory',
    mode    => $mode,
    require => File['/usr/safenet/lunaclient/cert/'],
  }

  $me = $facts['networking']['fqdn']
  $luna_cert = "/etc/luna/cert/client/${me}.pem"
  $luna_key  = "/etc/luna/cert/client/${me}Key.pem"
  $dst_cert  = "/usr/safenet/lunaclient/cert/client/${me}.pem"
  $dst_key   = "/usr/safenet/lunaclient/cert/client/${me}Key.pem"

  $cert_exists = generate('/bin/sh', '-c', "test -f ${luna_cert} && echo yes || echo no").strip

  if $cert_exists == 'yes' {
    # Copy existing certs from /etc/luna/cert
    exec { "copy_luna_cert_${me}":
      command => "cp ${luna_cert} ${dst_cert} && cp ${luna_key} ${dst_key}",
      creates => $dst_cert,
      path    => ['/usr/bin', '/bin'],
      require => File['/usr/safenet/lunaclient/cert/client/'],
    }
  } else {
    # Generate new key and cert
    sunet::snippets::keygen { $me:
      key_file  => $dst_key,
      cert_file => $dst_cert,
    }
  }

  file { $dst_cert:
    mode    => $mode,
    require => $cert_exists ? {
      'yes'   => Exec["copy_luna_cert_${me}"],
      default => Sunet::Snippets::Keygen[$me],
    },
  }

  file { $dst_key:
    mode    => $mode,
    require => $cert_exists ? {
      'yes'   => Exec["copy_luna_cert_${me}"],
      default => Sunet::Snippets::Keygen[$me],
    },
  }
}
