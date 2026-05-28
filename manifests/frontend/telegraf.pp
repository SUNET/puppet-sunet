# Setup and run one Telegraf per frontend
define sunet::frontend::telegraf(
  String           $docker_image          = 'docker.sunet.se/eduid/telegraf',
  String           $docker_imagetag       = 'stable',
  Array[String]    $docker_volumes        = [],
  String           $basedir               = '/opt/frontend/telegraf',
  String           $username              = 'sunetfrontend',
  String           $group                 = 'sunetfrontend',
  Optional[String] $forward_url           = undef,
  String           $statsd_listen_address = '',  # empty for all addresses
  Integer          $statsd_listen_port    = 8125,
  Array[String]    $allow_clients         = ['172.16.0.0/12'],
)
{
  ensure_resource('sunet::system_user', $username, {
    username => $username,
    group    => $group,
  })

  exec { 'telegraf_mkdir':
    command => "/bin/mkdir -p ${basedir}",
    unless  => "/usr/bin/test -d ${basedir}",
  }

  file {
    "${basedir}/telegraf.conf":
      ensure  => 'file',
      mode    => '0640',
      group   => $group,
      require => Sunet::System_user[$username],
      content => template('sunet/frontend/load_balancer_telegraf.conf.erb'),
      notify  => [Sunet::Docker_run['sunetfrontend_telegraf']],
      ;
  }

  sunet::docker_run { 'sunetfrontend_telegraf':
    image    => $docker_image,
    imagetag => $docker_imagetag,
    expose   => ["${statsd_listen_port}/udp"],
    net      => 'host',  # listening on localhost with --net host is better than exposing ports that will sneak past ufw rules
    volumes  => flatten(["${basedir}/telegraf.conf:/etc/telegraf/telegraf.conf:ro",
                        $docker_volumes,
                        ]),
  }

  sunet::misc::ufw_allow { 'allow_telegraf_statsd':
    from  => $allow_clients,
    port  => $statsd_listen_port,
    proto => 'udp',
  }
}
