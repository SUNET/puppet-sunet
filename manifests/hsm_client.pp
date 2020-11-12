class sunet::hsm_client($luna_version="6.2") {
   $pkcs11pin = hiera('pkcs11pin',"")
   sunet::snippets::reinstall::keep {['/etc/luna','/etc/Chrystoki.conf.d']: } ->
   file {['/etc/luna','/etc/luna/cert']: ensure => directory } ->
   sunet::docker_run {"${name}_hsmproxy":
      hostname => "${::fqdn}",
      image    => 'docker.sunet.se/luna-client',
      imagetag => $luna_version,
      volumes  => ['/dev/log:/dev/log','/etc/Chrystoki.conf.d:/etc/Chrystoki.conf.d','/etc/luna/cert:/usr/safenet/lunaclient/cert'],
      env      => ["PKCS11PIN=${pkcs11pin}"],
      extra_parameters => ["--log-driver=syslog"]
   }
   sunet::scriptherder::cronjob { "${name}_restart_hsmproxy":
     cmd           => "/usr/sbin/service docker-${name}_hsmproxy restart",
     minute        => '9',
     hour          => '0',
     ok_criteria   => ['exit_status=0','max_age=48h'],
     warn_criteria => ['exit_status=1','max_age=50h'],
   }
}
