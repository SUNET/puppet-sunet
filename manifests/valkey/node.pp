# A valkey cluster class

# @param cluster_nodes       A list of all valkey cluster member FQDN's. Used when bootstrapping the cluster.
# @param cluster_ports        Default ports to use in the cluster, override if needed.
# @param cluster_node_timeout The maximum amount of time a Valkey Cluster node can be unavailable, without it being considered as failing.
# @param ca_cert_path         Path to CA root cert, override if you use a different CA
# @param valkey_loglevel      Configure the loglevel for valkey
# @param allow_clients        This is a list of client prefixes that should be allowed to talk to valkey
# @param allow_peers          This is the list of valkey server prefixes that are part of the cluster (used for nftables)
class sunet::valkey::node(
  Integer           $numnodes = 3,
  Boolean           $hostmode = true,
  Optional[Boolean] $tls = true,
  Optional[Boolean] $cluster = true,
  Optional[String]  $cluster_announce_ip = '',
  Array[String]     $cluster_nodes = [$facts['networking']['fqdn']],
  Array[Integer]    $cluster_ports = [6379,6380,6381],
  Optional[Integer] $cluster_node_timeout = 5000,
  Optional[Boolean] $automatic_rectify = true,
  Optional[Boolean] $prevent_reboot = true,
  Optional[String]  $image = 'valkey/valkey',
  Optional[String]  $image_tag = '9-alpine',
  Optional[String]  $maxmemory = undef,
  String            $maxmemory_policy = 'noeviction',
  String            $ca_cert_path = '/etc/ssl/certs/infra-2-prod.crt',
  Enum['debug', 'verbose', 'notice', 'warning'] $valkey_loglevel = 'notice',
  Array[String]     $allow_clients = [],
  Array[String]     $allow_peers = [],
)
{

  $fqdn = $facts['networking']['fqdn']
  $valkey_password = safe_hiera('valkey_password')

  # valkey-tools is not available on older OS'es, but redis-tools is compatible with valkey
  if ($facts['os']['name'] == 'Ubuntu' and versioncmp($facts['os']['release']['full'], '26.04') > 0)
    or ($facts['os']['name'] == 'Debian' and versioncmp($facts['os']['release']['major'], '13') > 0) {
    include sunet::packages::valkey_tools
    $cli_client = "valkey-cli"
  }
  else {
    include sunet::packages::redis_tools
    $cli_client = "redis-cli"
  }

  # Allow the user to either specify the variable in cosmos-rules or in hiera
  if $cluster_announce_ip == '' {
    $__cluster_announce_ip = lookup('cluster_announce_ip', undef, undef, '')
  } else {
    $__cluster_announce_ip = $cluster_announce_ip
  }
  # Allow the user to use the explicit string ipaddress or ipaddress6 to use the corresponding facts
  if $__cluster_announce_ip == 'ipaddress' {
    $_cluster_announce_ip = $facts['networking']['ip']
  } elsif $__cluster_announce_ip == 'ipaddress6' {
    $_cluster_announce_ip = $facts['networking']['ip6']
  } else {
    $_cluster_announce_ip = $__cluster_announce_ip
  }

  sunet::docker_compose { 'valkeycluster_compose':
    content          => template('sunet/valkey/docker-compose.yml.erb'),
    service_name     => 'valkey',
    compose_dir      => '/opt/',
    compose_filename => 'docker-compose.yml',
    description      => 'valkey Cluster',
  }
  file {'/etc/sysctl.d/55-vm-overcommit.conf':
    ensure  => present,
    content => template('sunet/valkey/55-vm-overcommit.conf.erb'),
  }
  file {'/opt/valkey/valkey-rectify.sh':
    ensure  => present,
    mode    => '0755',
    content => template('sunet/valkey/valkey-rectify.sh.erb'),
  }
  file {'/opt/valkey/bootstrap-valkey.sh':
    ensure  => present,
    mode    => '0755',
    content => template('sunet/valkey/bootstrap-valkey.sh.erb'),
  }
  file {'/usr/local/bin/valkey-connect':
    ensure  => present,
    mode    => '0755',
    content => template('sunet/valkey/valkey-connect.sh.erb'),
  }
  if $automatic_rectify {
    sunet::scriptherder::cronjob { 'valkey-rectify':
      cmd           => '/opt/valkey/valkey-rectify.sh',
      hour          => '*',
      minute        => '*/5',
      ok_criteria   => ['exit_status=0','max_age=2d'],
      warn_criteria => ['exit_status=1','max_age=3d'],
    }
  }

  if $prevent_reboot {
    include sunet::packages::cowsay
    file {'/etc/molly-guard/run.d/11-valkeycluster':
      ensure  => present,
      mode    => '0755',
      content => template('sunet/valkey/11-valkeycluster.erb'),
    }
  }

  file { '/etc/letsencrypt/renewal-hooks/deploy/valkey':
    ensure  => file,
    mode    => '0700',
    content => file('sunet/valkey/certbot-renewal-hook'),
  }

  range(0, $numnodes - 1).each |$i|{
    $clusterportnum = 16379 + $i
    $valkeyportnum = 6379 + $i

    file { "/opt/valkey/node-${i}":
      ensure => directory,
      owner  => '999',
      group  => '999',
    }
    -> file { "/opt/valkey/node-${i}/server.conf":
      ensure  => present,
      content => template('sunet/valkey/server.conf.erb'),
    }
    sunet::nftables::allow { "valkey_cluster_ports_${i}":
      from => [$allow_peers],
      port => [$valkeyportnum,$clusterportnum],
    }
    sunet::nftables::allow { "valkey_client_port_${i}":
      from => [$allow_clients],
      port => [$valkeyportnum],
    }
  }

  # Monitoring script that can be executed with NRPE
  file { '/usr/local/sbin/check-valkey-status':
    ensure  => 'file',
    mode    => '0755',
    owner   => 'root',
    content => file('sunet/valkey/check-valkey-status.py')
  }
  # sudo exceptions (needed to read cert files)
  file { '/etc/sudoers.d/sudoers-valkey':
    ensure  => 'file',
    mode    => '0440',
    owner   => 'root',
    content => file('sunet/valkey/sudoers-valkey')
  }
  # NRPE commands file
  file { '/etc/nagios/nrpe.d/nrpe-valkey.cfg':
    ensure  => 'file',
    mode    => '0644',
    owner   => 'root',
    content => file('sunet/valkey/nrpe-valkey.cfg')
  }

}
