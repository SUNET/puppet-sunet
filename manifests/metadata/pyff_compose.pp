# Run pyff with compose
class sunet::metadata::pyff_compose(
  String $pyff_imagetag='latest',
  String $luna_imagetag='latest',
  Array $pyff_extra_volumes = [],
  Array $luna_extra_volumes = [],
  Array $resolvers = [],
  Array $pyff_environments = [],
  Array $luna_environments = [],
  String $pyff_pipeline='mdx.fd',
  Integer $pyff_update_frequency=300,
  Integer $pyff_port=8080,
  String $pyff_credentialsdir = '/etc/credentials',
  String $pyff_datadir='/opt/metadata',
  String $pyff_loglevel='INFO',
  String $langs='en',
  Boolean $hsm_client = false,
  String $hostname = $facts['networking']['fqdn'],
  Boolean $manage_signing_key = false,
) {

  $pkcs11pin = lookup('pkcs11pin', undef, undef, '')

  if $manage_signing_key {
    exec {$pyff_credentialsdir:
      command => "mkdir -p ${pyff_credentialsdir}",
      unless  => "/usr/bin/test -d ${pyff_credentialsdir}"
    }
    ensure_resource('sunet::snippets::secret_file', "${pyff_credentialsdir}/pyff-signing-key.pem", {
      hiera_key => 'pyff_signing_key',
    })
  }

  sunet::docker_compose { 'pyff':
    content          => template('sunet/metadata/docker-compose-pyff.yml.erb'),
    service_name     => 'pyff',
    compose_dir      => '/opt/',
    compose_filename => 'docker-compose.yml',
    description      => 'pyff',
  }

  if $hsm_client {
    service {'docker-hsm_client_hsmproxy':
        ensure => 'stopped',
        enable => false,
    }
  }
}
