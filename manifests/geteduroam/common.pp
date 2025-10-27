# Get eduroam::common
class sunet::geteduroam::common(
){

  ensure_resource('sunet::misc::create_dir', '/opt/geteduroam/config', { owner => 'root', group => 'root', mode => '0750'})
  ensure_resource('sunet::misc::create_dir', '/opt/geteduroam/cert', { owner => 'root', group => 'root', mode => '0755'})

  $db_servers = lookup('mariadb_cluster_nodes', Array, undef, [])
  file { '/opt/geteduroam/haproxy.cfg':
    content => template('sunet/geteduroam/haproxy.cfg.erb'),
    mode    => '0755',
  }

}
