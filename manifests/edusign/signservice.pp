# signservice class
class sunet::edusign::signservice($version='latest', $host=undef, $ensure='present') {
  $_host = $host ? {
    undef    => $facts['networking']['fqdn'],
    default  => $host
  }
  sunet::docker_run{'signservice':
    ensure   => $ensure,
    image    => 'docker.sunet.se/edusign-signservice',
    imagetag => $version,
    ports    => ['443:8443'],
    volumes  => ['/var/log:/var/log',
                  '/etc/localtime:/etc/localtime:ro',
                  '/etc/edusign-signservice:/opt/edusign-signservice'],
    env      => ['SIGNSERVICE_HOME=/opt/edusign-signservice',
                  'SPRING_CONFIG_LOCATION=/opt/edusign-signservice/config/application.yml' ]
  }

  if $facts['sunet_nftables_opt_in'] == 'yes' or
    ( $facts['os']['name'] == 'Ubuntu' and versioncmp($facts['os']['release']['full'], '22.04') >= 0 ) {
    sunet::nftables::docker_expose { 'signservice' :
      allow_clients => ['130.242.125.110/32', '130.242.125.140/32'],
      port          => '443',
      iif           => $facts['interface_default'],
    }
    sunet::nftables::docker_expose { 'new_signservice' :
      allow_clients => ['any'],
      port          => '443',
      iif           => $facts['interface_default'],
    }
  }

  sunet::snippets::secret_file { '/etc/edusign-signservice/config/credentials/signservice.key':
    hiera_key => 'signservice_key'
  }
}
