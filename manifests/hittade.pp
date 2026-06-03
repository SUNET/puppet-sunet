# Setup the hittade service (Django app + postgres + redis)
#
# Relies on the node already being a dockerhost2 (the dockerhost2 fact); the
# sunet::docker_compose define is dockerhost2-aware and installs the right
# systemd unit. The config files mounted into the containers are dropped on
# the server out-of-band under $config_dir, Puppet only creates the directories.
#
# TLS termination and routing are handled by the nginx-proxy + acme-companion
# stack run by sunet::invent::receiver on the same host. This service is
# discovered via the VIRTUAL_HOST/LETSENCRYPT_HOST env vars in the compose file
# and reached over the receiver's external compose network (receiver_default).
# That means sunet::invent::receiver must also be declared on this node.
#
# @param hostname     Required. The public hostname nginx-proxy serves / fetches a Let's Encrypt cert for
# @param image        The hittade-server image (without tag)
# @param image_tag    The hittade-server image tag
# @param config_dir   Directory with the hand-dropped config (localsettings.py, urls.py, proxy.xml, certificates/)
# @param compose_dir  Parent dir for the compose project (data volumes live under ${compose_dir}/hittade/)
class sunet::hittade (
  String $hostname,
  String $image       = 'docker.sunet.se/hittade-server',
  String $image_tag   = '0.0.2',
  String $config_dir  = '/etc/hittade',
  String $compose_dir = '/opt',
) {

  # Directory for the hand-dropped config files (localsettings.py, urls.py,
  # proxy.xml). File contents are managed by the operator, Puppet only ensures
  # the directory exists.
  sunet::misc::create_dir { $config_dir:
    owner => 'root',
    group => 'root',
    mode  => '0755',
  }

  # Directory for certificates mounted into the web container, populated
  # out-of-band (secrets, not managed by Puppet). Owned by uid 999 so the
  # app user inside the container can read/traverse it. Plain file resource
  # (not create_dir) to avoid create_dir's User[$owner] dependency on uid 999.
  file { "${config_dir}/certificates":
    ensure  => directory,
    owner   => '999',
    group   => '999',
    mode    => '0700',
    require => Sunet::Misc::Create_dir[$config_dir],
  }

  # No firewall rules here: ports 80/443 are opened by sunet::invent::receiver,
  # whose nginx-proxy fronts this service.

  sunet::docker_compose { 'hittade':
    content          => template('sunet/hittade/docker-compose.yml.erb'),
    service_name     => 'hittade',
    compose_dir      => $compose_dir,
    compose_filename => 'docker-compose.yml',
    description      => 'hittade service',
  }
}
