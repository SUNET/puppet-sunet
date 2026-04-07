# A class to install and manage Forgejo runner(s)
class sunet::forgejo::runner::orchestrator (
  String $version           = '12.6.4',
  String $version_sha256sum = 'fe83c5d5fffbbb81f2f8d93f4638d098ad9c08b77aa6b5035856ae9643d25684',
  Integer $runners = 4,
  String $forgejo_instance  =  'platform.sunet.se',
  String $forgejo_prefix            = 'runner',
  String $openstack_key_name        = 'dirigenten',
  String $openstack_network         =  'public',
  String $dirigenten_version        = 'latest',
  Optional[String] $runner_image = undef,
) {

  $forgejo_registration_token = lookup('forgejo_registration_token', undef, undef, 'NOT_SET_IN_HIERA');

  file {'/opt/forgejo-runner-orchestrator':
    ensure => 'directory',
  }
  file {'/opt/forgejo-runner-orchestrator/bin':
    ensure => 'directory',
  }

  file {'/opt/forgejo-runner-orchestrator/libexec':
    ensure => 'directory',
  }

  file {'/opt/forgejo-runner-orchestrator/config':
    ensure => 'directory',
  }

  # Generate SSH-key used to access DB nodes
  $key_path = '/opt/forgejo-runner-orchestrator/config/id_ed25519'
  if lookup('forgejo_runner_ssh_key', undef, undef, undef) {
    ensure_resource('sunet::snippets::secret_file', $key_path, {
    hiera_key => 'forgejo_runner_ssh_key',
  })
  } else {
    if (!find_file($key_path)){
      sunet::snippets::ssh_keygen{$key_path:} # This will not overwrite an existing key
    }
  }

  file { '/opt/forgejo-runner-orchestrator/config/runner.config':
    ensure  => 'file',
    content => file('sunet/forgejo/runner-2.0.config'),
  }

  $clouds = lookup('clouds', undef, undef, {})
  file { '/opt/forgejo-runner-orchestrator/config/clouds.yaml':
    ensure  => file,
    content => to_yaml({'clouds' => $clouds}),
  }


  file { "/opt/forgejo-runner-orchestrator/bin/forgejo-runner-${version}":
    ensure         => 'file',
    source         => "https://code.forgejo.org/forgejo/runner/releases/download/v${version}/forgejo-runner-${version}-linux-amd64",
    checksum       => 'sha256',
    checksum_value => $version_sha256sum,
    mode           => '0755',
  }
  file { '/opt/forgejo-runner-orchestrator/bin/forgejo-runner':
    ensure => link,
    target => "/opt/forgejo-runner-orchestrator/bin/forgejo-runner-${version}",
  }

  file { '/opt/forgejo-runner-orchestrator/libexec/runner-orchestrator':
    ensure  => 'file',
    content => template('sunet/forgejo/runner-orchestrator.erb'),
    mode    => '0755',
  }

  file { '/opt/forgejo-runner-orchestrator/libexec/runner-wrapper':
    ensure  => 'file',
    content => template('sunet/forgejo/runner-wrapper.2.0.erb'),
    mode    => '0755',
  }

  file { '/usr/local/bin/runnerctl':
    ensure  => 'file',
    content => template('sunet/forgejo/runnerctl.erb'),
    mode    => '0755',
  }

  file { '/etc/systemd/system/sunet-forgejo-runner-orchestrator@.service':
    ensure  => 'file',
    content => file('sunet/forgejo/forgejo-runner-2.0.service'),
    mode    => '0644',
  }

  range(0, $runners - 1).each |$runner|{

    service { "sunet-forgejo-runner-orchestrator@runner-${runner}":
      ensure => 'running',
      enable => true,
    }
  }
}
