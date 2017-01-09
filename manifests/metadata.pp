define sunet::metadata($url=undef,
                       $cert=undef,
                       $filename=undef) 
{
   ensure_resource('package',['opensaml2-tools','wget'],{ensure => present})
   $local = $filename ? {
      undef   => $name,
      default => $local
   }
   $verify = $cert ? {
      undef   => "test -s ${local}.tmp",
      default => "samlsign -f ${local}.tmp -c ${cert}"
   }
   $safe_name = regsubst($name, '[^0-9A-Za-z.\-]', '-', 'G')
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

define sunet::metadata::swamid_idp {
   ensure_resource('file',"/var/run/md-signer2.crt", {
      content  => file("sunet/md-signer2.crt")
   })
   sunet::metadata { "swamid_idp": 
      url      => "http://mds.swamid.se/md/swamid_idp.xml",
      cert     => "/var/run/md-signer2.crt",
      filename => $name
   }
}
