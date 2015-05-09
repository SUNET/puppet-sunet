define sunet::ici_ca($pkcs11_module="/usr/lib/softhsm/libsofthsm.so",
                     $pkcs11_pin=undef,
                     $pkcs11_key_slot="0",
                     $pkcs11_key_id="abcd",
                     $autosign_dir=undef,
                     $autosign_type="peer",
                     $public_repo_url=undef,
                     $public_repo_dir=undef)
{
   apt::ppa {'ppa:leifj/ici': } ->
   package { 'ici': ensure => latest } ->
   exec { '${name}_setup_ca':
      command => "/usr/bin/ici ${name} init",
      creates => "/var/lib/ici/${name}"
   } ->
   file { '${name}_ca_config':
      path => "/var/lib/ici/${name}/ca.config",
      content => template("sunet/ici_ca/ca.config.erb")
   }
   if $public_repo_dir and $public_repo_url {
      cron {'ici_publish':
         command => "test -f /var/lib/ici/${name}/ca.crt && /usr/bin/ici ${name} gencrl && /usr/bin/ici ${name} publish ${public_repo_dir}",
         user    => "root",
         minute  => "*/5"
      }
   }
}

define sunet::ici_ca::autosign($ca=undef,
                               $autosign_dir=undef,
                               $autosign_type="client")
{
   cron {"ici_autosign_${name}":
         command => "test -f /var/lib/ici/${ca}/ca.crt && /usr/bin/ici ${ca} issue -t ${autosign_type} -d 365 --copy-extensions ${autosign_dir}",
         user    => "root",
         minute  => "*/5"
   }
}
