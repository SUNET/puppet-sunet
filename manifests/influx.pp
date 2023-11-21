# This puppet manifest is used to install and configure stuff
# related to influxdb. The previuos generation relied on server
# specific configuration specified in cosmos-site.pp in nunoc-ops.

# @param servername        The fqdn of the server or servicename?
# @param tcpserveraddress  The version of the influx container to run
class sunet::influx(
  String        $servicename='',
  String        $influxdb_version='latest',
  Array[String] $influx_producer_networks,
) {

  sunet::docker_run { 'influxdb2':
    image    => 'docker.sunet.se/docker-influxdb2',
    imagetag => $influxdb_version,
    volumes  => [
      '/etc/dehydrated:/etc/dehydrated',
      '/var/lib/influxdb:/var/lib/influxdb',
      '/usr/local/bin/backup-influx.sh:/usr/local/bin/backup-influx.sh:ro',
    ],
    env      => ["HOSTNAME=${servicename}"],
    ports    => ['8086:8086'],
  }

  sunet::docker_run { 'always-https':
    image => 'docker.sunet.se/always-https',
    ports => ['80:80'],
    env   => ['ACME_URL=http://acme-c.sunet.se/'],
  }

  # Create a script used to do backups of influxdb
  file {'/usr/local/bin/backup-influx.sh':
      ensure  => file,
      path    => '/usr/local/bin/backup-influx.sh',
      mode    => '0500',
      owner   => 'root',
      content => template('sunet/influx/backup-influx.sh.erb')
  }

  # Create cronjob to execute influxdb backup script
  sunet::scriptherder::cronjob { 'influx-backup':
    cmd           => 'docker exec influxdb2 /usr/local/bin/backup-influx.sh',
    minute        => '22',
    hour          => '2',
    ok_criteria   => ['exit_status=0', 'max_age=25h'],
    warn_criteria => ['exit_status=1', 'max_age=50h'],
  }

  # nftables
    sunet::misc::ufw_allow { 'allow_http':
    from => 'any',
    port => '80',
    proto => 'tcp',
  }

  sunet::misc::ufw_allow { 'allow_https':
    from => 'any',
    port => '443',
    proto => 'tcp',
  }

  sunet::misc::ufw_allow { 'allow_influx':
    from => $influx_producer_networks,
    port => '8086',
    proto => 'tcp',
  }

  sunet::nftables::docker_expose { 'allow_http' :
    allow_clients => 'any',
    port          => '80',
    iif           => "${interface_default}",
  }

  sunet::nftables::docker_expose { 'allow_https' :
    allow_clients => 'any',
    port          => '443',
    iif           => "${interface_default}",
  }

  # Port 8086 is used to access influxdb2 container
  sunet::nftables::docker_expose { 'allow-influxdb2' :
    allow_clients => 'any',
    port          => '8086',
    proto         => 'tcp',
    iif           => "${interface_default}",
  }
}
