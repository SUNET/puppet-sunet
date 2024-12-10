class sunet::edusign($version='1.0.0', $host=undef, $ensure='present') {
  $_host = $host ? {
    undef    => $facts['networking']['fqdn'],
    default  => $host
  }
  #file {'/etc/metadata': ensure => directory }
  #sunet::metadata::swamid_idp_transitive { "/etc/metadata/swamid-idp-transitive.xml": }
  sunet::docker_run{'signapp-sp':
    ensure   => $ensure,
    image    => 'docker.sunet.se/shibsp-ajp',
    imagetag => 'latest',
    volumes  => ['/var/log:/var/log','/etc/ssl:/etc/ssl','/etc/metadata:/etc/metadata:ro'],
    env      => ['BACKEND_URL=ajp://signapp:8009/',
                  'METADATA_FILE=/etc/metadata/swamid-idp-transitive.xml',
                  "SP_HOSTNAME=${_host}",
                  'SP_ABOUT=/open/login',
                  'PROTECTED_URL=/secure',
                  "CERTNAME=${facts['networking']['fqdn']}_infra",
                  'SP_CONTACT=noc@sunet.se',
                  'DISCO_URL=https://service.seamlessaccess.org/ds'],
    depends  => ['signapp'],
    ports    => ['443:443']
  }
  $cp = hiera('edusign_credential_password')
  $cp_geant = hiera('edusign_credential_password_geant')
  sunet::docker_run{'signapp':
    ensure   => $ensure,
    image    => 'docker.sunet.se/upload-sign-app',
    imagetag => $version,
    volumes  => ['/var/log:/var/log','/etc/ssl:/etc/ssl','/etc/localtime:/etc/localtime:ro','/etc/upload-sign-app:/etc/upload-sign-app'],
    env      => ['SPRING_CONFIG_ADDITIONAL_LOCATION=/etc/upload-sign-app/',
                  "SIGNSERVICE_CREDENTIAL_PASSWORD=${cp}",
                  "SIGNSERVICE_CREDENTIAL_KEY_PASSWORD=${cp}",
                  "SIGNSERVICE_CREDENTIAL_PASSWORD_GEANT=${cp_geant}",
                  "SIGNSERVICE_CREDENTIAL_KEY_PASSWORD_GEANT=${cp_geant}",
                  'SIGSP_CONFIG_DATADIR=/etc/upload-sign-app/']
  }
}
