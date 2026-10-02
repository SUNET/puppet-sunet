# Key and certificate for one SAML2 frontend/backend of sunet::tunnelbana.
#
# Files are `${keys_dir}/${end}-${slug}.key` and `.pem`. The key is taken from
# the Hiera key `tunnelbana_${end}_${slug}_key` if set, otherwise a self-signed
# pair is generated. With a Hiera key but no `tunnelbana_${end}_${slug}_cert`,
# the certificate is assumed to be shipped as a plain file (e.g. from cosmos),
# and only its ownership and mode are managed.
define sunet::tunnelbana::saml2_keypair(
  Enum['frontend', 'backend'] $end,
  String                      $slug,
  String                      $keys_dir,
  Any                         $service_to_notify = undef,
) {
  $key_file  = "${keys_dir}/${end}-${slug}.key"
  $cert_file = "${keys_dir}/${end}-${slug}.pem"
  $hiera_key  = lookup("tunnelbana_${end}_${slug}_key", undef, undef, undef)
  $hiera_cert = lookup("tunnelbana_${end}_${slug}_cert", undef, undef, undef)

  if $hiera_key != undef {
    sunet::snippets::secret_file { $key_file:
      hiera_key => "tunnelbana_${end}_${slug}_key",
      owner     => '10001',
      group     => '10001',
      mode      => '0400',
      notify    => $service_to_notify,
    }

    if $hiera_cert != undef {
      file { $cert_file:
        ensure  => file,
        owner   => '10001',
        group   => '10001',
        mode    => '0440',
        content => "${hiera_cert}\n",
        notify  => $service_to_notify,
      }
    } else {
      file { $cert_file:
        owner  => '10001',
        group  => '10001',
        mode   => '0440',
        notify => $service_to_notify,
      }
    }
  } else {
    sunet::snippets::keygen { "tunnelbana_${end}_${slug}":
      key_file  => $key_file,
      cert_file => $cert_file,
    }

    # keygen runs as root; the container user must be able to read the result.
    file {
      $key_file:
        owner   => '10001',
        group   => '10001',
        mode    => '0400',
        require => Sunet::Snippets::Keygen["tunnelbana_${end}_${slug}"],
        notify  => $service_to_notify,
        ;
      $cert_file:
        owner   => '10001',
        group   => '10001',
        mode    => '0440',
        require => Sunet::Snippets::Keygen["tunnelbana_${end}_${slug}"],
        notify  => $service_to_notify,
        ;
    }
  }
}
