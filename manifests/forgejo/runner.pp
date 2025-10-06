# A class to install and manage Forgejo runner(s)
class sunet::forgejo::runner (
  String $version           = '11.1.2',
  String $version_sha256sum = '6442d46db2434a227e567a116c379d0eddbe9e7a3f522596b25d31979fd59c8d',
  String $machine_version = '42.20250914.3.0',
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
  file {'/opt/forgejo-runner/images/unverified':
    ensure  => 'directory',
  }


  file {'/opt/forgejo-runner/trust':
    ensure  => 'directory',
  }

  file { '/opt/forgejo-runner/bin/forgejo-runner':
    ensure         => 'file',
    source         => "https://code.forgejo.org/forgejo/runner/releases/download/v${version}/forgejo-runner-${version}-linux-amd64",
    checksum       => 'sha256',
    checksum_value => $version_sha256sum,
    mode           => '0755',
  }

  file { '/opt/forgejo-runner/trust/fedora.gpg':
    ensure => 'file',
    content => file('sunet/forgejo/fedora.gpg'),
  }

  file { "/opt/forgejo-runner/images/unverified/fedora-coreos-${machine_version}-qemu.x86_64.qcow2.xz":
    ensure         => 'file',
    source         => "https://builds.coreos.fedoraproject.org/prod/streams/stable/builds/${machine_version}/x86_64/fedora-coreos-${machine_version}-qemu.x86_64.qcow2.xz",
    notify         =>  Exec["verify_image"],
  }

  exec { 'verify_image':
    command     => "/usr/bin/gpgv --keyring /opt/forgejo-runner/trust/fedora.gpg /opt/forgejo-runner/images/unverified/fedora-coreos-${machine_version}-qemu.x86_64.qcow2.xz",
    refreshonly => true,
  }

}
