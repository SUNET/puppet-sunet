# Setup and run one Telegraf per frontend
define sunet::frontend::telegraf(
  String           $docker_image    = 'docker.sunet.se/eduid/telegraf',
  String           $docker_imagetag = 'stable',
  String           $basedir         = '/opt/frontend/telegraf',
  String           $username        = 'sunetfrontend',
  String           $group           = 'sunetfrontend',
  Optional[String] $forward_url     = undef,
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
      content => template('sunet/frontend/load_balancer_telegraf.conf.erb')
      notify  => [Sunet::Docker_run['sunetfrontend_telegraf']],
      ;
  }

  sunet::docker_run { 'sunetfrontend_telegraf':
    image    => $docker_image,
    imagetag => $docker_imagetag,
    expose   => ['8125/udp'],
    net      => 'host',  # listening on localhost with --net host is better than exposing ports that will sneak past ufw rules
    volumes  => ["${basedir}/telegraf.conf:/etc/telegraf/telegraf.conf:ro",
                 '/etc/ssl/certs/infra.crt:/etc/telegraf/ca.pem:ro',
                 ]
  }
}
