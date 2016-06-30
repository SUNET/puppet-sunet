class glb($zone = undef,
          $geodns_version = 'latest',
          $dnslb_version  = 'latest',
          $bind_address = pick($::ipaddress_eth0, $::ipaddress_bond0,
                               $::ipaddress_br0, $::ipaddress_em1,
                               $::ipaddress_em2, $::ipaddress6_eth0,
                               $::ipaddress6_bond0, $::ipaddress6_br0,
                               $::ipaddress6_em1, $::ipaddress6_em2))
{
   file { '/etc/geodns':
      ensure => 'directory'
   }
   sunet::docker_run { 'geodns':
      image    => 'docker.sunet.se/geodns',
      imagetag  => $geodns_version,
      volumes  => ['/etc/geodns:/etc/geodns'],
      ports    => ["${bind_address}:53:5353/udp","${bind_address}:53:5353"],
      command  => "-port 5353"
   }
   sunet::docker_run { 'dnslb':
      image    => 'docker.sunet.se/dnslb',
      imagetag => $dnslb_version,
      volumes  => ['/etc/geodns:/etc/geodns'],
      env      => ["ZONE=${zone}"],
   }
   ufw::allow { "allow-dns-udp":
      ip   => "${bind_address}",
      port => 53,
      proto => "udp",
   }
   ufw::allow { "allow-dns-tcp":
      ip   => "${bind_address}",
      port => 53,
      proto => "tcp",
   }
   sunet::nagios::nrpe_check_process { 'geodns': }
}
