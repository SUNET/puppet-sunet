# A class to install and manage Forgejo runner(s)
class sunet::forgejo::runner (
  String $version           = '11.1.2',
  String $version_sha256sum = '6442d46db2434a227e567a116c379d0eddbe9e7a3f522596b25d31979fd59c8d',
  String $machine_image_url = '',
) {

  file {'/opt/forgejo-runner':
    ensure  => 'directory',
  }
  file {'/opt/forgejo-runner/bin':
    ensure  => 'directory',
  }

  file {'/opt/forgejo-runner/images':
    ensure  => 'directory',
  }

  file {'/opt/forgejo-runner/trust':
    ensure  => 'directory',
  }

  file { '/opt/forgejo-runner/bin/forgejo-runner':
    source         => "https://code.forgejo.org/forgejo/runner/releases/download/v${version}/forgejo-runner-${version}-linux-amd64",
    checksum       => 'sha256',
    checksum_value => $version_sha256sum,
    mode           => '0755',
    ensure         => 'file',
  }

  file { '/opt/forgejo-runner/trust/fedora.gpg':
    source         => file('sunet/forgejo/fedora.gpg'),
    ensure         => 'file',
  }

}
