require stdlib

class sunet::satosa($dehydrated_name=undef,
                    $image='docker.sunet.se/satosa',  # NOTE: this image appears abandoned, you probably want docker.sunet.se/docker-satosa
                    $tag='3.4-stable',
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
  ensure_resource('file','/etc/satosa/run', { ensure => directory } )
  ensure_resource('file','/etc/satosa/plugins', { ensure => directory } )
  ensure_resource('file','/etc/satosa/metadata', { ensure => directory } )
  $key_data = {}
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
  sunet::docker_run {'satosa':
    image    => $image,
    imagetag => $tag,
    volumes  => ['/etc/satosa:/etc/satosa','/etc/dehydrated:/etc/dehydrated'],
    ports    => ['443:8000'],
    env      => [
      'DATA_DIR=/etc/satosa',
      'METADATA_DIR=/etc/satosa/metadata',
    ]
  }
  file {'/etc/satosa/proxy_conf.yaml':
    content => inline_template("<%= @merged_conf.to_yaml %>\n"),
    notify  => Sunet::Docker_run['satosa']
  }
  $plugins = hiera('satosa_config')
  sort(keys($plugins)).each |$n| {
    $conf = hiera($n)
    $fn = $plugins[$n]
    file { $fn:
      content => inline_template("<%= @conf.to_yaml %>\n"),
      notify  => Sunet::Docker_run['satosa']
    }
  }
  ufw::allow { 'satosa-allow-https':
    ip   => 'any',
    port => '443'
  }
  $dehydrated_status = $dehydrated_name ? {
    undef   => 'absent',
    default => 'present'
  }
  sunet::docker_run {'alwayshttps':
    ensure => $dehydrated_status,
    image  => 'docker.sunet.se/always-https',
    ports  => ['80:80'],
    env    => ['ACME_URL=http://acme-c.sunet.se'],
  }
  ufw::allow { 'satosa-allow-http':
    ensure => $dehydrated_status,
    ip     => 'any',
    port   => '80',
  }
  if ($dehydrated_name) {
    file { '/etc/satosa/https.key': ensure => link, target => "/etc/dehydrated/certs/${dehydrated_name}.key" }
    file { '/etc/satosa/https.crt': ensure => link, target => "/etc/dehydrated/certs/${dehydrated_name}/fullchain.pem" }
  } else {
    sunet::snippets::keygen {'satosa_https':
      key_file  => '/etc/satosa/https.key',
      cert_file => '/etc/satosa/https.crt'
    }
  }
}
