# Ceph for SUNET
class sunet::ceph(
  Array  $adm,
  Array  $clients,
  String $type,
  String $firstmon,
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
  $nodes = lookup('nodes', undef, undef, []);
  if $type == 'adm' {
    $extra_ports = []
    include sunet::packages::cephadm
    $adm_private_key = lookup('adm_private_key', undef, undef, 'NOT_SET_IN_HIERA');
    $adm_keyring = lookup('adm_keyring', undef, undef, 'NOT_SET_IN_HIERA');

    file {'/etc/ceph/ceph.client.admin.keyring':
      ensure  => 'present',
      owner   => 'root',
      group   => 'root',
      mode    => '0600',
      content => $adm_keyring,
    }
    file {'/root/.ssh/id_ed25519_adm':
      ensure  => 'present',
      owner   => 'root',
      group   => 'root',
      mode    => '0600',
      content => $adm_private_key,
    }
    file {'/root/.ssh/id_ed25519_adm.pub':
      ensure  => 'present',
      owner   => 'root',
      group   => 'root',
      mode    => '0600',
      content => $adm_public_key,
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
    file {'/opt/ceph/cluster-bootstrap.sh':
      ensure  => 'file',
      owner   => 'root',
      group   => 'root',
      mode    => '0700',
      content => template('sunet/ceph/cluster-bootstrap.erb.sh'),
    }
  }
  elsif $type == 'osd' {
    $extra_ports = []
  }
  elsif $type == 'mds' {
    $extra_ports = []
  }
  elsif $type == 'firstmon' {
    include sunet::packages::cephadm
    file {'/root/.ssh/id_ed25519_adm':
      ensure  => 'present',
      owner   => 'root',
      group   => 'root',
      mode    => '0600',
      content => $adm_private_key,
    }
    file {'/root/.ssh/id_ed25519_adm.pub':
      ensure  => 'present',
      owner   => 'root',
      group   => 'root',
      mode    => '0600',
      content => $adm_public_key,
    }
    $extra_ports = [ { 'from' => $clients, 'to' => '3300' } ]
    file {'/opt/ceph':
      ensure  => 'directory',
    }
    file {'/opt/ceph/bootstrap.sh':
      ensure  => 'file',
      owner   => 'root',
      group   => 'root',
      mode    => '0700',
      content => template('sunet/ceph/bootstrap.erb.sh'),
    }
  }
  elsif $type == 'mon' {
    $extra_ports = [ { 'from' => $clients, 'to' => '3300' } ]
    file {'/opt/ceph':
      ensure  => 'directory',
    }
    sunet::nftables::allow { 'expose-allow-ssh':
      from => $adm,
      port => 22,
    }
  }
  $internal_nodes = $nodes.map |$node| {
    $node['addr']
  }
  $internal_ports = [ { 'from' => $internal_nodes, 'to' => ['22', '3300', '6800-7300'] } ]
  $ceph_ports = $extra_ports + $internal_ports
  $ceph_ports.each |$port| {
    sunet::nftables::allow { "expose-allow-${port['to']}":
      from => $port['from'],
      port => $port['to'],
    }
  }
}
