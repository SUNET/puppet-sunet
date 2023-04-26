class sunet::satosa(
  $dehydrated_name=undef,
  $image='docker.sunet.se/satosa',
  $interface = "${::facts['interface_default']}",
  $tag='8.0.1',
) {
   $proxy_conf = hiera("satosa_proxy_conf")
   $default_conf = { 
      "STATE_ENCRYPTION_KEY"       => hiera("satosa_state_encryption_key"),
      "USER_ID_HASH_SALT"          => hiera("satosa_user_id_hash_salt"),
      "CUSTOM_PLUGIN_MODULE_PATHS" => ["plugins"],
      "COOKIE_STATE_NAME"          => "SATOSA_STATE"
   }
   $merged_conf = merge($proxy_conf,$default_conf)
   ensure_resource('file','/etc', { ensure => directory } )
   ensure_resource('file','/etc/satosa', { ensure => directory } )
   ensure_resource('file',"/etc/satosa/", { ensure => directory } )
   ensure_resource('file',"/etc/satosa/run", { ensure => directory } )
   ensure_resource('file',"/etc/satosa/plugins", { ensure => directory } )
   ensure_resource('file',"/etc/satosa/metadata", { ensure => directory } )
   $key_data = {}
   ["backend","frontend","metadata"].each |$id| {
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
   file {"/etc/satosa/proxy_conf.yaml":
      content => inline_template("<%= @merged_conf.to_yaml %>\n"),
      notify  => Service['sunet-satosa'],
   }
   $plugins = hiera("satosa_config")
   sort(keys($plugins)).each |$n| {
      $conf = hiera($n)
      $fn = $plugins[$n]
      file { "$fn":
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
   sunet::docker_run {'alwayshttps':
      image    => 'docker.sunet.se/always-https',
      ports    => ['80:80'],
      env      => ['ACME_URL=http://acme-c.sunet.se'],
      ensure   => $dehydrated_status
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
   if ($dehydrated_name) {
      file { '/etc/satosa/https.key': ensure => link, target => "/etc/dehydrated/certs/$dehydrated_name.key" }
      file { '/etc/satosa/https.crt': ensure => link, target => "/etc/dehydrated/certs/${dehydrated_name}/fullchain.pem" }
   } else {
      sunet::snippets::keygen {"satosa_https":
         key_file  => "/etc/satosa/https.key",
         cert_file => "/etc/satosa/https.crt"
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
