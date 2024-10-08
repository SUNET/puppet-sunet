class sunet::wifiprobe {

  sunet::docker_run {'alwayshttps':
      image => 'docker.sunet.se/always-https',
      ports => ['80:80'],
      env   => ['ACME_URL=http://acme-c.sunet.se']
  }
    sunet::docker_run { 'wifiprobe':
        image    => 'wifiprobe-server',
        imagetag => 'latest',
        ports    => ['5000:5000', '443:443'],
        volumes  => ['/etc/ssh:/etc/ssh', '/opt/probe-website:/opt/probe-website'],
        env      => ['INSTALLDIR=/opt/probe-website'],
    }

}
