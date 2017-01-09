require stdlib

class satosa() {
   $state_encryption_key = hiera("satosa_state_encryption_key")
   $user_id_hash_salt = hiera("satosa_user_id_hash_salt")
   $proxy_conf = hiera("satosa_proxy_conf")
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
   $plugins = hiera("satosa-config")
   sort(keys($plugins)).each |$n| {
      $conf = hiera($n)
      file { "$plugins[$n]":
         content => inline_template("<%= @conf.to_yaml %>\n")
      }
   }
}
