# This puppet manifest is used to install and configure stuff
# related to influxdb. The previuos generation relied on server
# specific configuration specified in cosmos-site.pp in nunoc-ops.

# @param servername                The fqdn of the server or servicename?
# @param tcpserveraddress          The version of the influx container to run
# @param influx_producer_networks  A list of networks allowed to access influx port 8086
# @param legacy_settings           Set to false to switch to docker-compose, a never acme-d reload method & and dockerhostv2 nftable compability
class sunet::influx(
  String        $servicename='',
  String        $influxdb_version='latest',
  String        $influxdb2_tag='ci-docker-influxdb2-292',
  Array[String] $influx_producer_networks,
  Boolean       $legacy_settings = true,
) {

  if $legacy_settings{
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
  } else {
    # MUST be set properly in hiera to continue
    $influxdb_init_username = safe_hiera('influxdb_init_username')
    $influxdb_init_password = safe_hiera('influxdb_init_password')
    $influxdb_init_admin_token = safe_hiera('influxdb_init_admin_token')
    if $influxdb_init_username != 'NOT_SET_IN_HIERA' and $influxdb_init_password != 'NOT_SET_IN_HIERA' and $influxdb_init_admin_token != 'NOT_SET_IN_HIERA' {
      sunet::docker_compose { 'influxdb2':
        content          => template('sunet/influx/docker-compose-influxdb2.yml.erb'),
        service_name     => 'influxdb2',
        compose_dir      => '/opt/',
        compose_filename => 'docker-compose-influxdb2.yml',
        description      => 'influxdb2',
      }
    } else {
      notice("You need to set influxdb_init_username, influxdb_init_password, influxdb_init_admin_token in eyaml")
    }
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

  if $legacy_settings{
    # Cronjob for renewal of acme-d cert
    sunet::scriptherder::cronjob { 'le_renew':
      cmd     => '/usr/bin/certbot renew --post-hook "service docker-influxdb2 restart"',
      special => 'daily',
    }
  }
  else{
    file {'/etc/letsencrypt/renewal-hooks/post/certbot-acmed-renew-post-hook':
      ensure  => file,
      path    => '/etc/letsencrypt/renewal-hooks/post/certbot-acmed-renew-post-hook',
      mode    => '0500',
      owner   => 'root',
      content => template('sunet/influx/certbot-acmed-renew-post-hook.erb')
    }
  }

  # nftables
  # Port 8086 is used to access the influxdb2 container
  if $legacy_settings{
    sunet::nftables::docker_expose { 'allow-influxdb2' :
      allow_clients => $influx_producer_networks,
      port          => '8086',
      proto         => 'tcp',
      iif           => "${interface_default}",
    }
  } else {
    sunet::nftables::allow { 'allow-influxdb2-port':
      from  => $influx_producer_networks,
      port  => '8086',
      proto =>  'tcp'
    }
  }
}
