# For edusign validator service
class sunet::edusign::validator($version='1.0.2', $host=undef, $ensure='present') {
  $_host = $host ? {
      undef    => $facts['networking']['fqdn'],
      default  => $host
  }
  $pkcs11pin = safe_hiera('pkcs11pin')
  sunet::docker_run{'sigval':
      ensure   => $ensure,
      image    => 'docker.sunet.se/sigval',
      imagetag => $version,
      hostname => $facts['networking']['fqdn'],
      ports    => ['443:8443'],
      volumes  => ['/var/log:/var/log',
                  '/etc/ssl:/etc/ssl',
                  '/etc/Chrystoki.conf.d:/etc/Chrystoki.conf.d',
                  '/etc/luna/cert:/usr/safenet/lunaclient/cert',
                  '/etc/localtime:/etc/localtime:ro',
                  '/etc/sigval:/etc/sigval'],
      env      => ['SPRING_CONFIG_ADDITIONAL_LOCATION=/etc/sigval/',
                  "SIGVAL_SERVICE_PKCS11_PIN=${pkcs11pin}",
                  'TZ=Europe/Stockholm',
                  "TOMCAT_TLS_SERVER_KEY=/etc/ssl/private/${facts['networking']['fqdn']}_infra.key",
                  "TOMCAT_TLS_SERVER_CERTIFICATE=/etc/ssl/certs/${facts['networking']['fqdn']}_infra.crt",
                  'TOMCAT_TLS_SERVER_CERTIFICATE_CHAIN=/etc/ssl/certs/infra.crt']
  }

  if $facts['sunet_nftables_opt_in'] == 'yes' or ( $facts['os']['name'] == 'Ubuntu' and versioncmp($facts['os']['release']['full'], '22.04') >= 0 ) {
      sunet::nftables::docker_expose { 'signapi' :
        allow_clients => ['130.242.125.110/32', '130.242.125.140/32'],
        port          => '443',
        iif           => $facts['interface_default'],
      }
  }
}
