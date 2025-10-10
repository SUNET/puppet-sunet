# A class to install and manage Forgejo runner(s)
class sunet::forgejo::runner (
  String $version           = '11.1.2',
  String $version_sha256sum = '6442d46db2434a227e567a116c379d0eddbe9e7a3f522596b25d31979fd59c8d',
  String $machine_image     = 'quay.io/podman/machine-os:5.4',
  Integer $runners = 4,
  String $forgejo_instance  =  "platform.sunet.se",
) {

  include sunet::packages::podman
  include sunet::packages::virtiofsd
  include sunet::packages::qemu_system_x86
  include sunet::packages::gvproxy

  file {'/usr/lib/podman/gvproxy':
    ensure => 'link',
    target => '/usr/bin/gvproxy'
  }

  $registration_token = lookup('forgejo_registration_token', undef, undef, 'NOT_SET_IN_HIERA');

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
    mode    => '0644',
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

      file { "/home/${user}/runner.config":
        ensure  => 'file',
        content => template('sunet/forgejo/runner.config.erb'),
        mode    => '0700',
        owner   => $user,
      }

      service { "sunet-forgejo-runner@${user}":
        ensure => 'running',
        enable => true,
      }
    }
}
