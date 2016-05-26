define sunet::etcd_node(
  $disco_url       = undef,
  $initial_cluster = undef,
  $discovery_srv   = undef,
  $etcd_version    = 'v2.0.8',
  $proxy           = true,
  $etcd_ipaddr     = $::ipaddress_eth1,
  $etcd_image      = 'quay.io/coreos/etcd',
)
{
   include stdlib

   file { ["/data/${name}","/data/${name}/${::hostname}"]: ensure => 'directory' }
   $common_args = ["--name ${::hostname}",
            "--data-dir /data",
            "--key-file /etc/ssl/private/${::fqdn}_infra.key",
            "--ca-file /etc/ssl/certs/infra.crt",
            "--cert-file /etc/ssl/certs/${::fqdn}_infra.crt"]
   $disco_args = $disco_url ? {
      undef   => $initial_cluster ? {
         undef   => $discovery_srv ? {
            undef   => [],
            default => ["--discovery-srv ${discovery_srv}"]
         },
         default => ["--initial_cluster ${initial_cluster}"]
      },
      default => ["--discovery ${disco_url}"]
   }
   if $proxy {
      $args = concat($common_args,concat($disco_args,["--proxy on","--listen-client-urls http://0.0.0.0:4001,http://0.0.0.0:2379"]))
   } else {
      $args = concat($common_args,concat($disco_args,["--initial-advertise-peer-urls http://${etcd_ipaddr}:2380",
            "--advertise-client-urls http://${etcd_ipaddr}:2379",
            "--listen-peer-urls http://0.0.0.0:2380",
            "--listen-client-urls http://0.0.0.0:4001,http://0.0.0.0:2379",
            "--peer-key-file /etc/ssl/private/${::fqdn}_infra.key",
            "--peer-ca-file /etc/ssl/certs/infra.crt",
            "--peer-cert-file /etc/ssl/certs/${::fqdn}_infra.crt"]))
   }
   sunet::docker_run { "etcd_${name}":
      image            => $etcd_image,
      imagetag         => $etcd_version,
      volumes          => ["/data/${name}:/data","/etc/ssl:/etc/ssl"],
      command          => join($args," "),
      ports            => ["${etcd_ipaddr}:2380:2380","${etcd_ipaddr}:2379:2379","${::ipaddress_docker0}:4001:2379"],
   }
   if !$proxy {
      sunet::docker_run { "etcd_browser_${name}":
         image         => 'docker.sunet.se/etcd-browser',
         ports         => [ "${etcd_ipaddr}:8000:8000" ],
         start_on      => "docker-etcd-${name}",
         stop_on       => "docker-etcd-${name}"
      }
      ufw::allow { "allow-etcd-client-on-docker0":
         ip   => "${::ipaddress_docker0}",
         port => 4001
      }
      ufw::allow { "allow-etcd-peer":
         ip   => "${etcd_ipaddr}",
         port => 2380
      }
      ufw::allow { "allow-etcd-client":
         ip   => "${etcd_ipaddr}",
         port => 2379
      }
   }
}
