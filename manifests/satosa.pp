# Class to run Satosa in docker-compose
class sunet::satosa(
  Optional[String] $dehydrated_name = undef,
  String           $image           = 'docker.sunet.se/satosa',
  String           $interface       = $::facts['interface_default'],
  String           $tag             = '8.0.1',
  Optional[String] $redirect_uri    = lookup('redirect_uri', undef, undef, ''),
  Boolean          $enable_oidc     = false,
) {
  $proxy_conf = hiera('satosa_proxy_conf')
  $default_conf = {
    'STATE_ENCRYPTION_KEY'       => hiera('satosa_state_encryption_key'),
    'USER_ID_HASH_SALT'          => hiera('satosa_user_id_hash_salt'),
    'CUSTOM_PLUGIN_MODULE_PATHS' => ['plugins'],
    'COOKIE_STATE_NAME'          => 'SATOSA_STATE'
  }
  $merged_conf = merge($proxy_conf,$default_conf)
  ensure_resource('file','/etc', { ensure => directory } )
  ensure_resource('file','/etc/satosa', { ensure => directory } )
  ensure_resource('file','/etc/satosa/', { ensure => directory } )
  ensure_resource('file','/etc/satosa/run', { ensure => directory } )
  ensure_resource('file','/etc/satosa/plugins', { ensure => directory } )
  ensure_resource('file','/etc/satosa/metadata', { ensure => directory } )
  ensure_resource('file','/etc/satosa/md-signer2.crt', {
    content  => file('sunet/md-signer2.crt')
  })
  ['backend','frontend','metadata'].each |$id| {
    if hiera("satosa_${id}_key",undef) != undef {
      sunet::snippets::secret_file { "/etc/satosa/${id}.key": hiera_key => "satosa_${id}_key" }
      # assume cert is in cosmos repo
    } else {
      # make key pair
      sunet::snippets::keygen {"satosa_${id}":
        key_file  => "/etc/satosa/${id}.key",
        cert_file => "/etc/satosa/${id}.crt"
      }
    }
  }
  file {'/etc/satosa/proxy_conf.yaml':
    content => inline_template("<%= @merged_conf.to_yaml %>\n"),
    notify  => Service['sunet-satosa'],
  }
  $plugins = hiera('satosa_config')
  sort(keys($plugins)).each |$n| {
    $conf = hiera($n)
    $fn = $plugins[$n]
    file { $fn:
      content => inline_template("<%= @conf.to_yaml %>\n"),
      notify  => Service['sunet-satosa'],
    }
  }

  if $::facts['sunet_nftables_enabled'] == 'yes' {
    sunet::nftables::docker_expose { 'allow_https' :
      iif           => $interface,
      allow_clients => 'any',
      port          => 443,
    }
  } else {
    sunet::misc::ufw_allow { 'allow-https':
      from => 'any',
      port => '443'
    }
  }
  $dehydrated_status = $dehydrated_name ? {
    undef   => 'absent',
    default => 'present'
  }

  if ($dehydrated_name) {
    class { 'sunet::dehydrated::client':
      domain    => $dehydrated_name,
      ssl_links => true,
    }

    if $::facts['sunet_nftables_enabled'] == 'yes' {
      sunet::nftables::docker_expose { 'allow_http' :
        iif           => $interface,
        allow_clients => 'any',
        port          => 80,
      }
    } else {
      sunet::misc::ufw_allow { 'allow-http':
        from => 'any',
        port => '80'
      }
    }
    file { '/etc/satosa/https.key': ensure => link, target => "/etc/dehydrated/certs/${dehydrated_name}.key" }
    file { '/etc/satosa/https.crt': ensure => link, target => "/etc/dehydrated/certs/${dehydrated_name}/fullchain.pem" }
  } else {
    sunet::snippets::keygen {'satosa_https':
      key_file  => '/etc/satosa/https.key',
      cert_file => '/etc/satosa/https.crt'
    }
  }

  if ($enable_oidc) {
    $client_id     = lookup('client_id')
    $client_secret = lookup('client_secret')
    file { '/etc/satosa/cdb.json':
      ensure  => file,
      content => template('sunet/satosa/cdb.json.erb')
    }
  }

  service {'docker-satosa.service':
    ensure => 'stopped',
    enable => false,
  }
  service {'docker-alwayshttps.service':
    ensure => 'stopped',
    enable => false,
  }
  sunet::docker_compose { 'satosa_compose':
    content          => template('sunet/satosa/docker-compose.yml.erb'),
    service_name     => 'satosa',
    compose_dir      => '/opt/',
    compose_filename => 'docker-compose.yml',
    description      => 'Satosa',
  }
}
