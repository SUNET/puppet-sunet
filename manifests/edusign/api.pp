# api class
class sunet::edusign::api(
  String		$version	= '1.0.0',
  Optional[String] 	$host		= undef,
  String 		$ensure		= 'present',
  Array[String]		$loadbalancers  = [],
  Array[String]		$app_clients    = []
) {
  $_host = $host ? {
    undef    => $facts['networking']['fqdn'],
    default  => $host
  }
  $cp = hiera('edusign_credential_password')
  $cp_geant = hiera('edusign_credential_password_geant')
  sunet::snippets::reinstall::keep { '/etc/signservice-rest/keys/sp-keystore.jks': }
  sunet::snippets::reinstall::keep { '/etc/signservice-rest/keys/edusign-test-geant.jks': }
  sunet::snippets::reinstall::keep { '/etc/signservice-rest/signservice-users.properties': }
  sunet::docker_run{'signservice-rest':
    ensure   => $ensure,
    image    => 'docker.sunet.se/signservice-integration-rest',
    imagetag => $version,
    ports    => ['443:8443','127.0.0.1:444:8444'],
    volumes  => ['/var/log:/var/log','/etc/ssl:/etc/ssl','/etc/localtime:/etc/localtime:ro','/etc/signservice-rest:/etc/signservice-rest'],
    hostname => $facts['networking']['fqdn'],
    env      => ['SPRING_CONFIG_ADDITIONAL_LOCATION=/etc/signservice-rest/',
                  "SIGNSERVICE_CREDENTIAL_PASSWORD=${cp}",
                  "SIGNSERVICE_CREDENTIAL_KEY_PASSWORD=${cp}",
                  "SIGNSERVICE_CREDENTIAL_PASSWORD_GEANT=${cp_geant}",
                  "SIGNSERVICE_CREDENTIAL_KEY_PASSWORD_GEANT=${cp_geant}"]
  }
  if $facts['sunet_nftables_opt_in'] == 'yes' or ( $facts['os']['name'] == 'Ubuntu' and versioncmp($facts['os']['release']['full'], '22.04') >= 0 ) {
    sunet::nftables::docker_expose { 'signapi' :
      allow_clients => $loadbalancers + $app_clients,
      port          => '443',
      iif           => $facts['interface_default'],
    }
  }
}
