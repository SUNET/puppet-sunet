define sunet::luna_client($hostname = undef) {
   $client_hostname = $hostname ? {
      undef    => "${::fqdn}",
      default  => $hostname
   }
   $pin = lookup('luna_partition_password', undef, undef, undef)
   sunet::docker_run { "${name}-luna-client":
      image    => 'docker.sunet.se/luna-client',
      imagetag => 'latest',
      env      => ["PKCS11PIN=${pin}"],
      volumes  => ["/dev/log:/dev/log","/etc/luna/cert:/usr/safenet/lunaclient/cert"],
      hostname => $client_hostname
   }
}
