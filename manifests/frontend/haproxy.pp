define sunet::frontend::haproxy(
  String  $username = 'haproxy',
  String  $group    = 'haproxy',
  String  $basedir  = '/opt/frontend/haproxy',
  # Variables used in haproxy-config-update.erb
  Integer $registration_age_limit = 600,
  String  $haproxy_service_name   = 'docker-load-balancer-haproxy',
)
{
  include sunet::systemd_reload

  ensure_resource('sunet::system_user', $username, {
    username => $username,
    group    => $group,
  })

  exec { 'haproxy_mkdir':
    command => "/bin/mkdir -p ${basedir}",
    unless  => "/usr/bin/test -d ${basedir}",
  } ->
  file {
    "$basedir/etc":
      ensure  => 'directory',
      mode    => '0750',
      group   => $group,
      require => Sunet::System_user[$username],
      ;
    "$basedir/etc/haproxy.cfg":
      ensure  => 'file',
      mode    => '0640',
      group   => $group,
      require => Sunet::System_user[$username],
      force   => true,
      content => template("sunet/frontend/haproxy.cfg.erb")
      ;
    "$basedir/run":
      ensure  => 'directory',
      mode    => '0770',
      group   => $group,
      require => Sunet::System_user[$username],
      ;
    "$basedir/scripts":
      ensure  => 'directory',
      mode    => '0755',
      ;
    "$basedir/scripts/haproxy-config-update":
      ensure  => 'file',
      mode    => '0755',
      content => template("sunet/frontend/haproxy-config-update.erb")
      ;
    "$basedir/scripts/haproxy-status":
      ensure  => 'file',
      mode    => '0755',
      content => template("sunet/frontend/haproxy-status.erb")
      ;
    '/etc/systemd/system/haproxy-config-update.service':
      content => template('sunet/frontend/haproxy-config-update.service.erb'),
      notify  => [Class['sunet::systemd_reload'],
                  Service['haproxy-config-update'],
                  ],
      ;
  }

  service { 'haproxy-config-update':
    ensure  => 'running',
    enable  => true,
  }

  $fe_cfg = "${basedir}/etc/haproxy-frontends.cfg"
  $be_cfg = "${basedir}/etc/haproxy-backends.cfg"
  concat { $fe_cfg:
    owner    => 'root',
    group    => $group,
    mode     => '0640',
    notify   => Sunet::Docker_run["${name}_haproxy"],
  } ->
  exec { "create_${be_cfg}":
    command => "/bin/touch ${be_cfg} && chown root:${group} ${be_cfg} && chmod 640 ${be_cfg}",
    unless  => "/usr/bin/test -f ${be_cfg}",
    require => File["${basedir}/etc"],
  } ->

  sunet::docker_run { "${name}_haproxy":
    image    => 'docker.sunet.se/library/haproxy',
    imagetag => 'stable',
    net      => 'host',
    volumes  => ["${basedir}/etc:/etc/haproxy:ro",
                 "${basedir}/run:/var/run/haproxy",
                 '/etc/ssl:/etc/ssl:ro',
                 '/etc/dehydrated:/etc/dehydrated:ro',
                 '/dev/log:/dev/log',
                 ],
    command  => 'haproxy-systemd-wrapper -p /run/haproxy.pid -f /etc/haproxy/haproxy.cfg -f /etc/haproxy/haproxy-frontends.cfg -f /etc/haproxy/haproxy-backends.cfg',
    require  => [File["$basedir/etc/haproxy.cfg"]],
  }
}
