require stdlib

class sunet::satosa {
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
   ["backend","frontend","https","metadata"].each |$id| {
      sunet::snippets::keygen {"satosa_${id}":
         key_file  => "/etc/satosa/${id}.key",
         cert_file => "/etc/satosa/${id}.crt"
      }
   }
   file {"/etc/satosa/proxy_conf.yaml":
      content => inline_template("<%= @merged_conf.to_yaml %>\n")
   }
   $plugins = hiera("satosa_config")
   sort(keys($plugins)).each |$n| {
      $conf = hiera($n)
      $fn = $plugins[$n]
      file { "$fn":
         content => inline_template("<%= @conf.to_yaml %>\n")
      }
   }
   sunet::docker_run {'satosa':
      image    => 'docker.sunet.se/satosa',
      imagetag => '3.0-stable',
      volumes  => ['/etc/satosa:/etc/satosa'],
      ports    => ['443:8000'],
      env      => ['METADATA_DIR=/etc/satosa/metadata']
   }
}
