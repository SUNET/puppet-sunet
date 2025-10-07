# A class to install and manage Forgejo runner(s)
class sunet::forgejo::runner (
  String $version           = '11.1.2',
  String $version_sha256sum = '6442d46db2434a227e567a116c379d0eddbe9e7a3f522596b25d31979fd59c8d',
  String $machine_version = '42.20250914.3.0',
  String $machine_sha256sum = 'de60a6a1f10723ef54621952665d3d72758a476fa32f58e47ce8756941f7bd75',
  Integer $runners = 4,
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

  file {'/opt/forgejo-runner/libexec':
    ensure  => 'directory',
  }

  file { '/opt/forgejo-runner/bin/forgejo-runner':
    ensure         => 'file',
    source         => "https://code.forgejo.org/forgejo/runner/releases/download/v${version}/forgejo-runner-${version}-linux-amd64",
    checksum       => 'sha256',
    checksum_value => $version_sha256sum,
    mode           => '0755',
  }

  $machine_image_path = "/opt/forgejo-runner/images/fedora-coreos-${machine_version}-qemu.x86_64.qcow2"
  $machine_image_path_xz = "${machine_image_path}.xz"

  file { '/opt/forgejo-runner/libexec/runner-systemd-wrapper':
    ensure => 'file',
    content => template('sunet/forgejo/runner-systemd-wrapper.erb'),
    mode           => '0755',
  }

  file { '/opt/forgejo-runner/libexec/runner-wrapper':
    ensure  => 'file',
    content => template('sunet/forgejo/runner-wrapper.erb'),
    mode    => '0755',
  }

  file { '/etc/systemd/system/sunet-forgejo-runner@.service':
    ensure  => 'file',
    content => file('sunet/forgejo/forgejo-runner.service'),
    mode    => '0744',
  }

  file { "${machine_image_path_xz}":
    ensure         => 'file',
    source         => "https://builds.coreos.fedoraproject.org/prod/streams/stable/builds/${machine_version}/x86_64/fedora-coreos-${machine_version}-qemu.x86_64.qcow2.xz",
    checksum       => 'sha256',
    checksum_value => $machine_sha256sum,
    notify         =>  Exec["unpack_image"],

  }

    exec { 'unpack_image':
    command     => "/usr/bin/unxz --keep ${machine_image_path_xz}",
    refreshonly => true,
  }

    range(0, $runners - 1).each |$runner|{
      $user = "runner-${runner}"

      user { $user:
        ensure     => 'present',
        groups     => ['kvm'],
        home       => "/home/${user}",
        managehome => true,
        notify     => Exec["linger_user_${runner}"]
      }

      exec { "linger_user_${runner}":
        command     => "/usr/bin/loginctl enable-linger ${user}",
        refreshonly => true,
      }
    }
}
