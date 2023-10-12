# This puppet manifest is used to install and configure stuff
# related to grafana. The previuos generation relied on a class
# in cosmos-site.pp in nunoc-ops.

# @param servicename       The fqdn of the servicename
# @param grafana_version   The version of the grafana container to run
class sunet::grafana(
  String        $servicename='',
  String        $grafana_version='latest',
) {

  sunet::system_user {'grafana': username => 'grafana', group => 'grafana' }
  $smtp_password = safe_hiera('smtp_password', 'NOT_SET')
  file { '/etc/grafana': ensure => 'directory', owner => 'grafana' }
  file { '/var/log/grafana': ensure => 'directory', mode => '775', owner => 'grafana' }
  file { '/var/lib/grafana': ensure => 'directory', mode => '775', owner => 'grafana' }
  file { '/usr/share/grafana': ensure => 'directory', mode => '775', owner => 'grafana' }

  file {'/etc/grafana/grafana.ini':
      ensure  => file,
      path    => '/etc/grafana/grafana.ini',
      mode    => '0440',
      owner   => 'grafana',
      content => template('sunet/grafana/grafana.ini.erb')
  }
  file {'/etc/grafana/provisioning/datasources/grafana2influxdb.yaml':
      ensure  => file,
      path    => '/etc/grafana/provisioning/datasources/grafana2influxdb.yaml',
      mode    => '0440',
      owner   => 'grafana',
      content => template('sunet/grafana/grafana2influxdb.yaml.erb')
  }

  sunet::docker_run {"grafana":
      hostname => "${servicename}",
      image    => 'docker.sunet.se/docker-grafana',
      volumes  => [
                  '/var/lib/grafana:/var/lib/grafana',
                  '/etc/grafana:/etc/grafana',
                  '/var/log/grafana:/var/log/grafana',
                  '/etc/dehydrated/certs:/etc/dehydrated/certs:ro',
                  '/etc/letsencrypt/archive:/etc/archive:ro',
                  '/etc/grafana/provisioning/datasources:/usr/share/grafana/conf/provisioning/datasources',
                  '/etc/grafana/provisioning/dashboards:/usr/share/grafana/conf/provisioning/dashboards',
      ],
      env      => ["HOSTNAME=${servicename}",'GF_PATHS_DATA=/var/lib/grafana','GF_PATHS_LOGS=/var/log/grafana'],
      ports    => ['443:3000'],
  }

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

  sunet::docker_run {'always-https':
    image => 'docker.sunet.se/always-https',
    ports => ['80:80'],
    env   => ['ACME_URL=http://acme-c.sunet.se/'],
  }
}
