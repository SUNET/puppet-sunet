# Setup and run one Telegraf per frontend
define sunet::lb::telegraf(
  String           $docker_image          = 'docker.sunet.se/eduid/telegraf',
  String           $docker_imagetag       = 'stable',
  Array[String]    $docker_volumes        = [],
  String           $basedir               = '/opt/frontend/telegraf',
  String           $username              = 'telegraf',
  String           $group                 = 'telegraf',
  Optional[String] $forward_url           = undef,
  String           $statsd_listen_address = '',  # empty for all addresses
  Integer          $statsd_listen_port    = 8125,
  Array[String]    $allow_clients         = ['172.16.0.0/12'],
  Boolean          $docker_run            = true,
)
{

  exec { 'telegraf_mkdir':
    command => "/bin/mkdir -p ${basedir}",
    unless  => "/usr/bin/test -d ${basedir}",
  }

  file {
    "${basedir}/telegraf.conf":
      ensure  => 'file',
      mode    => '0640',
      group   => $group,
      content => template('sunet/lb/load_balancer_telegraf.conf.erb'),
      #notify  => [Sunet::Docker_run['sunetfrontend_telegraf']],
      ;
  }

  if $docker_run {
    sunet::docker_run { 'sunetfrontend_telegraf':
      image    => $docker_image,
      imagetag => $docker_imagetag,
      expose   => ["${statsd_listen_port}/udp"],
      net      => 'host',  # listening on localhost with --net host is better than exposing ports that will sneak past ufw rules
      volumes  => flatten(["${basedir}/telegraf.conf:/etc/telegraf/telegraf.conf:ro",
                          $docker_volumes,
                          ]),
    }
  }

  sunet::misc::ufw_allow { 'allow_telegraf_statsd':
    from  => $allow_clients,
    port  => $statsd_listen_port,
    proto => 'udp',
  }
}
