require stdlib

define satosa() {
   $state_encryption_key = hiera("${title}-satosa-state-encryption-key")
   $user_id_hash_salt = hiera("${title}-satosa-user-id-hash-salt")
   $proxy_conf = hiera("${title}-satosa-proxy-conf")
   $proxy_conf['STATE_ENCRYPTION_KEY'] = $state_encryption_key
   $proxy_conf['USER_ID_HASH_SALT'] = $user_id_hash_salt
   $proxy_conf['CUSTOM_PLUGIN_MODULE_PATHS'] = ['plugins']
   ensure_resource('file','/etc', { ensure => directory } )
   ensure_resource('file','/etc/satosa', { ensure => directory } )
   ensure_resource('file',"/etc/satosa/${title}", { ensure => directory } )
   ensure_resource('file',"/etc/satosa/${title}/run", { ensure => directory } )
   ensure_resource('file',"/etc/satosa/${title}/plugins", { ensure => directory } )
   ensure_resource('file',"/etc/satosa/${title}/metadata", { ensure => directory } )
   ["backend","frontend","https","metadata"].each |$id| {
      sunet::snippets::keygen {"$name_$id_keygen":
         key_file  => "/etc/satosa/${title}/$id.key",
         cert_file => "/etc/satosa/${title}/$id.crt"
      }
   }
   file {"/etc/satosa/${title}/proxy_conf.yaml":
      content => inline_template("<%= @proxy_conf.to_yaml %>\n")
   }
}
