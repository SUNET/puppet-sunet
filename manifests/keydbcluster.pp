# A cluster class
class sunet::keydbcluster(
  Integer $numnodes = 3,
  Boolean $hostmode = false,
  String  $docker_image = 'eqalpha/keydb',
  String  $docker_tag = 'x86_64_v6.3.4',
  Optional[Boolean] $tls = false,
  Optional[String] $cluster_announce_ip = '',
  Optional[Boolean] $automatic_rectify = false,
  Optional[Boolean] $prevent_reboot = false,
)
{

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

  $keydb_password = safe_hiera('keydb_password')

  sunet::docker_compose { 'keydbcluster_compose':
    content          => template('sunet/keydbcluster/docker-compose.yml.erb'),
    service_name     => 'keydb',
    compose_dir      => '/opt/',
    compose_filename => 'docker-compose.yml',
    description      => 'KeyDB Cluster',
  }
  file {'/etc/sysctl.d/55-vm-overcommit.conf':
    ensure  => present,
    content => template('sunet/keydbcluster/55-vm-overcommit.conf.erb'),
  }
  file {'/opt/keydb-rectify.sh':
    ensure  => present,
    mode    => '0755',
    content => template('sunet/keydbcluster/keydb-rectify.sh.erb'),
  }
  if $automatic_rectify {
    sunet::scriptherder::cronjob { 'keydb-rectify':
      cmd           => '/opt/keydb-rectify.sh',
      hour          => '*',
      minute        => '*/10',
      ok_criteria   => ['exit_status=0','max_age=2d'],
      warn_criteria => ['exit_status=1','max_age=3d'],
    }
  }

  if $prevent_reboot {
    include sunet::packages::cowsay
    file {'/etc/molly-guard/run.d/11-keydbcluster':
      ensure  => present,
      mode    => '0755',
      content => template('sunet/keydbcluster/11-keydbcluster.erb'),
    }
  }

  range(0, $numnodes - 1).each |$i|{
    $clusterportnum = 16379 + $i
    $keydbportnum = 6379 + $i

    file { "/opt/keydb/node-${i}":
      ensure  => directory,
    }
    -> file { "/opt/keydb/node-${i}/server.conf":
      ensure  => present,
      content => template('sunet/keydbcluster/server.conf.erb'),
    }
    if $::facts['sunet_nftables_enabled'] == 'yes' or $::facts['dockerhost_advanced_network'] == 'yes' or $::facts['dockerhost2'] == 'yes' {
      $ports = [$keydbportnum, $clusterportnum]
      $ports.each|$port| {
        sunet::nftables::rule { "keydb_port_${port}":
          rule => "add rule inet filter input tcp dport ${port} counter accept comment \"allow-keydb-${port}\""
        }
      }
    } else {
      sunet::misc::ufw_allow { "keydb_port_${i}":
        from => '0.0.0.0/0',
        port => [$keydbportnum,$clusterportnum],
      }
    }
  }
}
