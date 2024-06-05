# Wrapper to setup a MDQ-publiser
class sunet::metadata::mdq_publisher(
  Boolean $infra_cert_from_this_class = true,
  Boolean $nftables_init = true,
  Optional[String] $publisher_cert="/etc/ssl/certs/${facts['networking']['fqdn']}_infra.crt",
  Optional[String] $publisher_key="/etc/ssl/private/${facts['networking']['fqdn']}_infra.key",
  Optional[Array] $env=[],
  Optional[Integer] $valid_until=12,
  Optional[String] $validate_cert='/var/www/html/md/md-signer2.crt',
  Optional[String] $extra_entities='',
  Optional[String] $xml_dir='md',
  Optional[String] $imagetag='latest',
) {
  if $::facts['sunet_nftables_enabled'] != 'yes' {
    notice('Enabling UFW')
    include ufw
  } elsif $nftables_init {
    notice('Enabling nftables (opt-in, or Ubuntu >= 22.04)')
    ensure_resource ('class','sunet::nftables::init', {})
  }

  $signers = lookup('signers')
  $signers.each |$signer_name, $signer| {
    $signer_ip = $signer['ipnumber']
    $ssh_key = $signer['ssh_key']
    $ssh_key_type = $signer['ssh_key_type']
    if ($ssh_key and $ssh_key_type) {
      sunet::rrsync {"${signer_name}-dir":
        dir                => '/var/www/html',
        ro                 => false,
        ssh_key            => $ssh_key,
        ssh_key_type       => $ssh_key_type,
        use_sunet_ssh_keys => true,
      }
    }

    if ($signer_ip) {
      notice("allow-ssh-from-${signer_name} -> ${signer_ip}")
      sunet::misc::ufw_allow { "allow-ssh-from-${signer_name}":
        from => $signer_ip,
        port => 22
      }
    }
  }

  package { ['libxml2-utils','xmlsec1']: ensure => 'present' }

  file {
    '/var/www': ensure => directory, mode => '0755'
  } -> file {
    '/var/www/html': ensure => directory, mode => '0755', owner => 'www-data', group =>'www-data'
  } -> sunet::nagios::nrpe_check_fileage {
    'metadata_aggregate':
      filename     => '/var/www/html/entities/index.html', # yes this is correct
      warning_age  => '600',
      critical_age => '86400'
  }
  ensure_resource('file', '/usr/bin/check-metadata.sh', {
    ensure  => 'file',
    owner   => 'root',
    group   => 'root',
    mode    => '0755',
    content => template('sunet/metadata/check-metadata.erb'),
  })
  sunet::scriptherder::cronjob { 'check-metadata':
    cmd           => "/usr/bin/check-metadata.sh /var/www/html/${xml_dir} ${valid_until} ${validate_cert} ${extra_entities}",
    minute        => '*/15',
    ok_criteria   => ['exit_status=0', 'max_age=2h'],
    warn_criteria => ['exit_status=1', 'max_age=5h'],
  }

  if $infra_cert_from_this_class {
    sunet::ici_ca::rp { 'infra': }
  }
  $env_certs = [
        "PUBLISHER_CERT=${publisher_cert}",
        "PUBLISHER_KEY=${publisher_key}",
  ]

  sunet::docker_run { 'swamid-mdq-publisher':
    image               => 'docker.sunet.se/swamid/mdq-publisher',
    imagetag            => $imagetag,
    hostname            => $facts['networking']['fqdn'],
    volumes             => [
      '/etc/ssl:/etc/ssl',
      '/var/www/html:/var/www/html',
      '/etc/dehydrated:/etc/dehydrated',
    ],
    env                 => $env + $env_certs,
    uid_gid_consistency => false,
    ports               => ['443:443'],
  }

  if $::facts['sunet_nftables_enabled'] == 'yes' {
    sunet::nftables::docker_expose { 'expose publisher' :
      allow_clients => 'any',
      port          => 443,
      iif           => $facts['networking']['primary'],
    }
  } else {
    sunet::misc::ufw_allow { 'allow-https':
      from => 'any',
      port => '443'
    }
  }
}
