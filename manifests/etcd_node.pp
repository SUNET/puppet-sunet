define sunet::etcd_node(
  $disco_url       = undef,
  $initial_cluster = undef,
  $discovery_srv   = undef,
  $etcd_version    = 'v2.0.8',
  $proxy           = true,
  $docker_net      = 'docker',
  $etcd_s2s_ip     = $::ipaddress_eth1,
  $etcd_s2s_proto  = 'http',    # XXX default ought to be https
  $etcd_c2s_ip     = '0.0.0.0',
  $etcd_c2s_proto  = 'http',    # XXX default ought to be https
  $etcd_image      = 'quay.io/coreos/etcd',
  $tls_key_file    = "/etc/ssl/private/${::fqdn}_infra.key",
  $tls_ca_file     = '/etc/ssl/certs/infra.crt',
  $tls_cert_file   = "/etc/ssl/certs/${::fqdn}_infra.crt",
)
{
   include stdlib

   # Add brackets to bare IPv6 IP.
   $s2s_ip = $etcd_s2s_ip ? {
     /^[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}$/ => $etcd_s2s_ip,  # IPv4
     /^[0-9a-fA-F:]+$/ => "[${etcd_s2s_ip}]",
   }

   # Add brackets to bare IPv6 IP.
   $c2s_ip = $etcd_c2s_ip ? {
     /^[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}$/ => $etcd_c2s_ip,  # IPv4
     /^[0-9a-fA-F:]+$/ => "[${etcd_c2s_ip}]",
   }

   file { ['/data', "/data/${name}", "/data/${name}/${::hostname}"]:
     ensure => 'directory',
     mode   => '0700',
   }

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
   $common_args = [$disco_args,
                   "--name ${::hostname}",
                   '--data-dir /data',
                   "--key-file ${tls_key_file}",
                   "--ca-file ${tls_ca_file}",
                   "--cert-file ${tls_cert_file}",
                   $etcd_extra,
                   ]
   # interpolation simplifications
   $c2s_url = "${etcd_c2s_proto}://${c2s_ip}"
   $s2s_url = "${etcd_s2s_proto}://${s2s_ip}"
   if $proxy {
      $args = flatten([$common_args,
                       '--proxy on',
                       "--listen-client-urls ${c2s_url}:4001,${c2s_url}:2379",
                       ])
   } else {
      $args = flatten(["--advertise-client-urls ${c2s_url}:2379",
                       "--listen-client-urls ${c2s_url}:2379,${c2s_url}:4001",
                       "--initial-advertise-peer-urls ${s2s_url}:2380",
                       "--listen-peer-urls ${s2s_url}:2380",
                       "--peer-key-file ${tls_key_file}",
                       "--peer-ca-file ${tls_ca_file}",
                       "--peer-cert-file ${tls_cert_file}",
                       ])
   }
   sunet::docker_run { "etcd_${name}":
      image            => $etcd_image,
      imagetag         => $etcd_version,
      volumes          => ["/data/${name}:/data","/etc/ssl:/etc/ssl"],
      command          => join($args," "),
      ports            => ["2380:2380","2379:2379","${::ipaddress_docker0}:4001:2379"],  # XXX listening on all interfaces now
      net              => $docker_net,
   }
   if ! $proxy {
      sunet::docker_run { "etcd_browser_${name}":
         image         => 'docker.sunet.se/etcd-browser',
         ports         => [ "8000:8000" ],  # XXX listening on all interfaces now
         depends       => ["etcd_${name}"],
      }
      ufw::allow { "allow-etcd-client-on-docker0":
         ip   => "${::ipaddress_docker0}",
         port => 4001
      }
      ufw::allow { "allow-etcd-peer":
         ip   => $etcd_s2s_ip,
         port => 2380
      }
      ufw::allow { "allow-etcd-client":
         ip   => $etcd_c2s_ip,
         port => 2379
      }
   }
}
