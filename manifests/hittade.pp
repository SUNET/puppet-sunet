# Setup the hittade service (Django app + postgres + redis), fronted by Caddy
#
# Relies on the node already being a dockerhost2 (the dockerhost2 fact); the
# sunet::docker_compose define is dockerhost2-aware and installs the right
# systemd unit. The config files mounted into the containers are dropped on
# the server out-of-band under $config_dir, Puppet only creates the directories.
#
# @param hostname     Required. The public hostname Caddy serves / fetches a Let's Encrypt cert for
# @param image        The hittade-server image (without tag)
# @param image_tag    The hittade-server image tag
# @param caddy_tag    The caddy image tag
# @param config_dir   Directory with the hand-dropped config and the managed Caddyfile
# @param compose_dir  Parent dir for the compose project (data volumes live under ${compose_dir}/hittade/)
class sunet::hittade (
  String $hostname,
  String $image       = 'docker.sunet.se/hittade-server',
  String $image_tag   = '0.0.2',
  String $caddy_tag   = '2.11.4',
  String $config_dir  = '/etc/hittade',
  String $compose_dir = '/opt',
) {

  # Directory for the hand-dropped config files (localsettings.py, urls.py,
  # proxy.xml) and the Puppet-managed Caddyfile. File contents are managed by
  # the operator, Puppet only ensures the directory exists.
  sunet::misc::create_dir { $config_dir:
    owner => 'root',
    group => 'root',
    mode  => '0755',
  }

  # Directory for certificates mounted into the web container, populated
  # out-of-band (secrets, not managed by Puppet).
  sunet::misc::create_dir { "${config_dir}/certificates":
    owner => 'root',
    group => 'root',
    mode  => '0700',
  }

  # Caddy config, derived from the $hostname parameter so it is Puppet-managed.
  file { "${config_dir}/Caddyfile":
    ensure  => file,
    owner   => 'root',
    group   => 'root',
    mode    => '0644',
    content => template('sunet/hittade/Caddyfile.erb'),
  }

  # Caddy terminates TLS and needs to be reachable from the internet for the
  # ACME HTTP challenge (80) and to serve traffic (443).
  sunet::nftables::allow { 'allow-http':
    from => 'any',
    port => 80,
  }
  sunet::nftables::allow { 'allow-https':
    from => 'any',
    port => 443,
  }

  sunet::docker_compose { 'hittade':
    content          => template('sunet/hittade/docker-compose.yml.erb'),
    service_name     => 'hittade',
    compose_dir      => $compose_dir,
    compose_filename => 'docker-compose.yml',
    description      => 'hittade service',
  }
}
