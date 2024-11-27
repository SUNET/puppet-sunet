# Ceph for SUNET
class sunet::ceph(
  Array  $adm,
  Array  $clients,
  Array  $osd,
  String $type,
)
{
  $adm_public_key = lookup('adm_public_key', undef, undef, 'NOT_SET_IN_HIERA');
  file {'/root/.ssh/':
    ensure => 'directory',
    owner  => 'root',
    group  => 'root',
    mode   => '0700',
  }
  file {'/root/.ssh/authorized_keys':
    ensure => 'present',
    owner  => 'root',
    group  => 'root',
    mode   => '0600',
  }
  file_line { 'adm_public_key':
    path => '/root/.ssh/authorized_keys',
    line => $adm_public_key,
  }
  include sunet::packages::ceph_common
  if $type == 'adm' {
    include sunet::packages::cephadm
    $adm_private_key = lookup('adm_private_key', undef, undef, 'NOT_SET_IN_HIERA');
    $nodes = lookup('nodes', undef, undef, []);
    file {'/root/.ssh/id_ed25519_adm':
      ensure  => 'present',
      owner   => 'root',
      group   => 'root',
      mode    => '0600',
      content => $adm_private_key,
    }
    file {'/opt/ceph':
      ensure  => 'directory',
    }
    file {'/opt/ceph/ceph-cluster.yaml':
      ensure  => 'file',
      owner   => 'root',
      group   => 'root',
      mode    => '0600',
      content => template('sunet/ceph/ceph-cluster.erb.yaml'),
    }
  }
  elsif $type == 'osd' {
    $extra_ports = []
    include sunet::packages::ceph_osd
  }
  elsif $type == 'mds' {
    $extra_ports = []
    include sunet::packages::ceph_mds
  }
  elsif $type == 'mon' {
    $extra_ports = [ { 'from' => $clients, 'to' => '3300' } ]
    include sunet::packages::ceph_mon
  }
  sunet::nftables::allow { 'expose-allow-ssh':
    from => $adm,
    port => 22,
  }
  $internal_nodes = $nodes.map |$node| {
    $node['addr']
  }
  $internal_ports = [ { 'from' => $internal_nodes, 'to' => '6800-7300' } ]
  $ceph_ports = $extra_ports + $internal_ports
  $ceph_ports.each |$port| {
    sunet::nftables::allow { "expose-allow-${port['to']}":
      from => $port['from'],
      port => $port['to'],
    }
  }
}
