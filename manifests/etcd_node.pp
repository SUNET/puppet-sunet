define sunet::etcd_node(
   $disco_url    =   undef,
   $etcd_version =   'v2.0.8',
   $proxy        =   true
)
{
   include stdlib

   file { ["/data/${name}","/data/${name}/${::hostname}"]: ensure => 'directory' }
   $common_args = ["--discovery ${disco_url}",
            "--name ${::hostname}",
            "--data-dir /data",
            "--key-file /etc/ssl/private/${::fqdn}_infra.key",
            "--ca-file /etc/ssl/certs/infra.crt",
            "--cert-file /etc/ssl/certs/${::fqdn}_infra.crt"]
   if $proxy {
      $args = concat($common_args,["--proxy on","--listen-client-urls http://0.0.0.0:4001,http://0.0.0.0:2379"])
   } else {
      $args = concat($common_args,["--initial-advertise-peer-urls http://${::ipaddress_eth1}:2380",
            "--advertise-client-urls http://${::ipaddress_eth1}:2379",
            "--listen-peer-urls http://0.0.0.0:2380",
            "--listen-client-urls http://0.0.0.0:4001,http://0.0.0.0:2379",
            "--peer-key-file /etc/ssl/private/${::fqdn}_infra.key",
            "--peer-ca-file /etc/ssl/certs/infra.crt",
            "--peer-cert-file /etc/ssl/certs/${::fqdn}_infra.crt"])
   }
   sunet::docker_run { "etcd_${name}":
      image            => 'quay.io/coreos/etcd',
      imagetag         => $etcd_version,
      volumes          => ["/data/${name}:/data","/etc/ssl:/etc/ssl"],
      command          => join($args," "),
      ports            => ["${::ipaddress_eth1}:2380:2380","${::ipaddress_eth1}:2379:2379","${::ipaddress_docker0}:4001:2379"]
   }
   if !$proxy {
      sunet::docker_run { "etcd_browser_${name}":
         image         => 'docker.sunet.se/etcd-browser',
         volumes       => [ "/etc/ssl:/etc/ssl" ],
         env           => [ "ETCDCTL_CA_FILE=/etc/ssl/certs/infra.crt",
                            "ETCDCTL_KEY_FILE=/etc/ssl/private/${::fqdn}_infra.key",
                            "ETCDCTL_CERT_FILE=/etc/ssl/certs/${::fqdn}_infra.crt" ],
         ports         => [ "${::ipaddress_eth1}:8000:8000" ]
      }
      ufw::allow { "allow-etcd-peer":
         ip   => "${::ipaddress_eth1}",
         port => 2380
      }
      ufw::allow { "allow-etcd-client":
         ip   => "${::ipaddress_eth1}",
         port => 2379
      }
   }
}
