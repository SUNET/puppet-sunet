class sunet::hsm_client($luna_version="6.2") {
   $pkcs11pin = lookup('pkcs11pin', undef, undef, '')
   sunet::snippets::reinstall::keep {['/etc/luna','/etc/Chrystoki.conf.d']: } ->
   file {['/etc/luna','/etc/luna/cert']: ensure => directory } ->
   sunet::docker_run {"hsm_client_hsmproxy":
      hostname => "${::fqdn}",
      image    => 'docker.sunet.se/luna-client',
      imagetag => $luna_version,
      volumes  => ['/dev/log:/dev/log','/etc/Chrystoki.conf.d:/etc/Chrystoki.conf.d','/etc/luna/cert:/usr/safenet/lunaclient/cert'],
      env      => ["PKCS11PIN=${pkcs11pin}"],
      extra_parameters => ["--log-driver=syslog"]
   }
   sunet::scriptherder::cronjob { "hsm_client_restart_hsmproxy":
     cmd           => "/usr/sbin/service docker-hsm_client_hsmproxy restart",
     minute        => '9',
     hour          => '0',
     ok_criteria   => ['exit_status=0','max_age=48h'],
     warn_criteria => ['exit_status=1','max_age=50h'],
   }
}
