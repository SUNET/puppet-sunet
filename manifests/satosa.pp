require stdlib

class satosa() {
   $state_encryption_key = hiera("satosa-state-encryption-key")
   $user_id_hash_salt = hiera("satosa-user-id-hash-salt")
   $proxy_conf = hiera("satosa-proxy-conf")
   $proxy_conf['STATE_ENCRYPTION_KEY'] = $state_encryption_key
   $proxy_conf['USER_ID_HASH_SALT'] = $user_id_hash_salt
   $proxy_conf['CUSTOM_PLUGIN_MODULE_PATHS'] = ['plugins']
   if !$proxy_conf['COOKIE_STATE_NAME'] {
      $proxy_conf['COOKIE_STATE_NAME'] = "SATOSA_STATE"
   }
   if !$proxy_conf['CUSTOM_PLUGIN_MODULE_PATHS'] {
      $proxy_conf['CUSTOM_PLUGIN_MODULE_PATHS'] = ["plugins"]
   }
   ensure_resource('file','/etc', { ensure => directory } )
   ensure_resource('file','/etc/satosa', { ensure => directory } )
   ensure_resource('file',"/etc/satosa/", { ensure => directory } )
   ensure_resource('file',"/etc/satosa/run", { ensure => directory } )
   ensure_resource('file',"/etc/satosa/plugins", { ensure => directory } )
   ensure_resource('file',"/etc/satosa/metadata", { ensure => directory } )
   ["backend","frontend","https","metadata"].each |$id| {
      sunet::snippets::keygen {"$name_$id_keygen":
         key_file  => "/etc/satosa/$id.key",
         cert_file => "/etc/satosa/$id.crt"
      }
   }
   file {"/etc/satosa/proxy_conf.yaml":
      content => inline_template("<%= @proxy_conf.to_yaml %>\n")
   }
}

define satosa::plugin($file_name = undef) {
   require satosa
   $fn = $file_name ? {
      undef   => "/etc/satosa/plugins/${title}.yaml",
      default => $file_name
   }
   $conf = hiera("${title}")
   file {"$fn":
      content => inline_template("<%= @conf.to_yaml %>\n")
   }
}
