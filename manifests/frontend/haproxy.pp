define sunet::frontend::haproxy(
  $username = 'haproxy',
  $group    = 'haproxy',
  $basedir  = '/opt/frontend/haproxy',
)
{
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
    "$basedir/run":
      ensure  => 'directory',
      mode    => '0770',
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
  }

  $fe_cfg = "${basedir}/etc/haproxy-frontends.cfg"
  $be_cfg = "${basedir}/etc/haproxy-backends.cfg"
  exec { "create_${fe_cfg}":
    command => "/bin/touch ${fe_cfg} && chown root:${group} ${fe_cfg} && chmod 640 ${fe_cfg}",
    unless  => "/usr/bin/test -f ${fe_cfg}",
    require => File["${basedir}/etc"],
  } ->
  exec { "create_${be_cfg}":
    command => "/bin/touch ${be_cfg} && chown root:${group} ${be_cfg} && chmod 640 ${be_cfg}",
    unless  => "/usr/bin/test -f ${be_cfg}",
    require => File["${basedir}/etc"],
  } ->

  sunet::docker_run { $name:
    image    => 'docker.sunet.se/library/haproxy',
    imagetag => 'stable',
    net      => 'host',
    volumes  => ["${basedir}/etc:/etc/haproxy:ro",
                 "${basedir}/run:/var/run/haproxy",
                 '/etc/ssl:/etc/ssl:ro',
                 ],
    command  => 'haproxy-systemd-wrapper -p /run/haproxy.pid -f /etc/haproxy/haproxy.cfg -f /etc/haproxy/haproxy-frontends.cfg -f /etc/haproxy/haproxy-backends.cfg',
    require  => [File["$basedir/etc/haproxy.cfg"]],
  }
}
