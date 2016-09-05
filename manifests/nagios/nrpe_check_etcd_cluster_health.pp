define sunet::nagios::nrpe_check_etcd_cluster_health ($etcd_container = $title) {
   sunet::sudoer {'nagios_get_etcd_cluster-health':
       user_name    => 'nagios',
       collection   => 'nagios',
       command_line => '/usr/local/bin/get_etcd_cluster-health $etcd_container'
   }
   sunet::sudoer {'nagios_get_docker_container_id':
       user_name    => 'nagios',
       collection   => 'nagios',
       command_line => '/usr/local/bin/get_docker_container_id $etcd_container'
   }
   file { '/usr/lib/nagios/plugins/etcd-cluster-health':
       ensure  => 'file',
       mode    => '0555',
       group   => 'nagios',
       require => Package['nagios-nrpe-server'],
       content => template('sunet/nagioshost/etcd-cluster-health.erb'),
   }
   file { '/usr/local/bin/get_docker_container_id':
       ensure  => 'file',
       mode    => '0555',
       group   => 'nagios',
       require => Package['nagios-nrpe-server'],
       content => template('sunet/nagioshost/get_docker_container_id.erb'),
   }
   file { '/usr/local/bin/get_etcd_cluster-health':
       ensure  => 'file',
       mode    => '0555',
       group   => 'nagios',
       require => Package['nagios-nrpe-server'],
       content => template('sunet/nagioshost/get_etcd_cluster-health.erb'),
   }
   sunet::nagios::nrpe_command {'etcd_cluster_health':
       command_line => '/usr/lib/nagios/plugins/etcd-cluster-health $etcd_container'
   }
}
