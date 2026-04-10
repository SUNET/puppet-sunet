#
# A valkey cluster class

# @param cluster_nodes        A list of all valkey cluster member FQDN's. Used when bootstrapping the cluster.
# @param cluster_ports        Default ports to use in the cluster, override if needed.
# @param ca_cert_path         Path to CA root cert, override if you use a different CA
class sunet::valkey::node(
  Integer           $numnodes = 3,
  Boolean           $hostmode = true,
  Optional[Boolean] $tls = true,
  Optional[Boolean] $cluster = true,
  Optional[String]  $cluster_announce_ip = '',
  Array[String]     $cluster_nodes = [$facts['networking']['fqdn']],
  Array[Integer]    $cluster_ports = [6379,6380,6381],
  Optional[Boolean] $automatic_rectify = true,
  Optional[Boolean] $prevent_reboot = true,
  Optional[String]  $image = 'valkey/valkey',
  Optional[String]  $image_tag = '9-alpine',
  Optional[String]  $maxmemory = undef,
  String            $maxmemory_policy = 'noeviction',
  String            $ca_cert_path = '/etc/ssl/certs/infra-2-prod.crt',
  Array[String]     $allow_clients = [],
  Array[String]     $allow_peers = [],
)
{

  $fqdn = $facts['networking']['fqdn']
  $valkey_password = safe_hiera('valkey_password')

  # valkey-tools is not available, but redis-tools is compatible with valkey
  include sunet::packages::redis_tools

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
      minute        => '*/10',
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
}
