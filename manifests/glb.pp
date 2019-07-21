class sunet::glb(
          $zone = undef,
          $geodns_version = 'latest',
          $dnslb_version  = 'latest'
{
   file { '/etc/geodns':
      ensure => 'directory'
   }
   sunet::docker_run { 'geodns':
      image    => 'docker.sunet.se/geodns',
      imagetag  => $geodns_version,
      volumes  => ['/etc/geodns:/etc/geodns'],
      ports    => ["${::ipaddress_default}:53:5353/udp","${::ipaddress_default}:53:5353"],
      command  => "-port 5353"
   }
   sunet::docker_run { 'dnslb':
      image    => 'docker.sunet.se/dnslb',
      imagetag => $dnslb_version,
      volumes  => ['/etc/geodns:/etc/geodns'],
      env      => ["ZONE=${zone}"],
   }
   ufw::allow { "allow-dns-udp":
      ip   => "${::ipaddress_default}",
      port => '53',
      proto => "udp",
   }
   ufw::allow { "allow-dns-tcp":
      ip   => "${::ipaddress_default}",
      port => '53',
      proto => "tcp",
   }
   sunet::nagios::nrpe_check_process { 'geodns': }
}
