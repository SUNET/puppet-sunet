# Wrapper to setup a MDQ-publiser
class sunet::metadata::mdq_publisher(
  String $dir='/var/www/html',
  Optional[String] $cert_name=undef,
  Optional[Array] $env=[],
) {
  if $::facts['sunet_nftables_enabled'] != 'yes' {
    notice('Enabling UFW')
    include ufw
  } else {
    notice('Enabling nftables (opt-in, or Ubuntu >= 22.04)')
    ensure_resource ('class','sunet::nftables::init', {})
  }

  $signers = hiera('signers')
  $signers.each |$signer_name, $signer| {
    $signer_ip = $signer['ipnumber']
    $ssh_key = $signer['ssh_key']
    $ssh_key_type = $signer['ssh_key_type']
    if ($ssh_key and $ssh_key_type) {
      sunet::rrsync {"${signer_name}-dir":
        dir                => $dir,
        ro                 => false,
        ssh_key            => $ssh_key,
        ssh_key_type       => $ssh_key_type,
        use_sunet_ssh_keys => false,
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
  file {'/etc/ssl/mdq':
    ensure => 'directory'
  }
  if ($cert_name != undef) {
    file {'/etc/ssl/mdq/privkey.pem':
      ensure => 'link',
      target => "/etc/ssl/private/${cert_name}.key"
    }
    file {'/etc/ssl/mdq/cert.pem':
      ensure => 'link',
      target => "/etc/ssl/certs/${cert_name}.crt"
    }
  } else {
    exec { "${title}_key":
      command => 'openssl genrsa -out /etc/ssl/mdq/privkey.pem 4096',
      onlyif  => 'test ! -f /etc/ssl/mdq/privkey.pem',
      creates => '/etc/ssl/mdq/privkey.pem'
    }
    -> exec { "${title}_cert":
      command => "openssl req -x509 -sha256 -new -days 3650 -subj \"/CN=${title}\" -key /etc/ssl/mdq/privkey.pem -out /etc/ssl/mdq/cert.pem",
      onlyif  => 'test ! -f /etc/ssl/mdq/cert.pem -a -f /etc/ssl/mdq/privkey.pem',
      creates => '/etc/ssl/mdq/cert.pem'
    }
  }
  sunet::docker_run { 'swamid-mdq-publisher':
    image               => 'docker.sunet.se/swamid/mdq-publisher',
    imagetag            => 'latest',
    hostname            => $hostname,
    volumes             => [
      '/etc/ssl/mdq:/etc/certs',
      '/etc/ssl:/etc/ssl',
      '/var/www/html:/var/www/html'
    ],
    env                 => $env,
    uid_gid_consistency => false,
    ports               => ['443:443'],
  }

  if $::facts['sunet_nftables_enabled'] == 'yes' {
    sunet::nftables::docker_expose { 'expose publisher' :
      allow_clients => 'any',
      port          => 443,
      iif           => $facts['networking']['primary'],
    }
  }
  sunet::misc::ufw_allow { 'allow-https':
    from => 'any',
    port => '443'
  }
}
