# This puppet manifest is used to install and configure stuff
# related to influxdb. The previuos generation relied on server
# specific configuration specified in cosmos-site.pp in nunoc-ops.

# @param servername                The fqdn of the server or servicename?
# @param tcpserveraddress          The version of the influx container to run
# @param influx_producer_networks  A list of networks allowed to access influx port 8086
class sunet::influx(
  String        $servicename='',
  String        $influxdb_version='latest',
  Array[String] $influx_producer_networks,
) {

  sunet::docker_run { 'influxdb2':
    image    => 'docker.sunet.se/docker-influxdb2',
    imagetag => $influxdb_version,
    volumes  => [
      '/etc/letsencrypt/live/:/etc/letsencrypt/live/:ro',
      '/etc/letsencrypt/archive:/etc/letsencrypt/archive:ro',
      '/data:/var/lib/influxdb',
      '/usr/local/bin/backup-influx.sh:/usr/local/bin/backup-influx.sh:ro',
    ],
    env      => ["SERVICENAME=${servicename}"],
    ports    => ['8086:8086'],
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
  # Port 8086 is used to access the influxdb2 container
  sunet::nftables::docker_expose { 'allow-influxdb2' :
    allow_clients => $influx_producer_networks,
    port          => '8086',
    proto         => 'tcp',
    iif           => "${interface_default}",
  }
}
