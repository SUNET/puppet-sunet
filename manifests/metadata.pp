define sunet::metadata($url=undef,
                       $cert=undef,
                       $filename=undef) 
{
   ensure_resource('package',['wget','xmlsec1'],{ensure => present})
   $local = $filename ? {
      undef   => $title,
      default => $filename
   }
   $verify = $cert ? {
      undef   => "test -s ${local}.tmp",
      default => "xmlsec1 --verify --pubkey-cert-pem ${cert} --id-attr:ID  urn:oasis:names:tc:SAML:2.0:metadata:EntitiesDescriptor ${local}.tmp"
   }
   $safe_name = regsubst($title, '[^0-9A-Za-z.\-]', '-', 'G')
   $fetch = "fetch_${safe_name}"
   cron {$fetch:
      command => "/usr/bin/wget --no-check-certificate -q ${url} -N -O ${local}.tmp && chmod 0644 ${local}.tmp && ${verify} && mv ${local}.tmp ${local}",
      user    => 'root',
      minute  => '*/5'
   }
}

define sunet::metadata::swamid {
   ensure_resource('file',"/var/run/md-signer2.crt", {
      content  => file("sunet/md-signer2.crt")
   })
   sunet::metadata { "swamid":
      url      => "http://mds.swamid.se/md/swamid-2.0.xml",
      cert     => "/var/run/md-signer2.crt",
      filename => $name
   }
}

define sunet::metadata::swamid_testing {
   ensure_resource('file',"/var/run/md-signer2.crt", {
      content  => file("sunet/md-signer2.crt")
   })
   sunet::metadata { "swamid":
      url      => "http://mds.swamid.se/md/swamid-testing-1.0.xml",
      cert     => "/var/run/md-signer2.crt",
      filename => $name
   }
}

define sunet::metadata::swamid_idp {
   ensure_resource('file',"/var/run/md-signer2.crt", {
      content  => file("sunet/md-signer2.crt")
   })
   sunet::metadata { "swamid_idp":
      url      => "http://mds.swamid.se/md/swamid-idp.xml",
      cert     => "/var/run/md-signer2.crt",
      filename => $name
   }
}

define sunet::metadata::swamid_idp_transitive {
   ensure_resource('file',"/var/run/md-signer2.crt", {
      content  => file("sunet/md-signer2.crt")
   })
   sunet::metadata { "swamid_idp_transitive":
      url      => "http://mds.swamid.se/md/swamid-idp-transitive.xml",
      cert     => "/var/run/md-signer2.crt",
      filename => $name
   }
}
