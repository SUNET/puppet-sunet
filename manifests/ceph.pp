# Ceph for SUNET
class sunet::ceph(
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
    include sunet::packages::ceph_osd
  }
  elsif $type == 'mds' {
    include sunet::packages::ceph_mds
  }
  elsif $type == 'mon' {
    include sunet::packages::ceph_mon
  }

}
