define sunet::etcd_node(
  $disco_url       = undef,
  $initial_cluster = undef,
  $discovery_srv   = undef,
  $etcd_version    = 'v2.0.8',
  $proxy           = true,
  $proxy_readonly  = false,
  $docker_net      = 'docker',
  $etcd_s2s_ip     = $::ipaddress_eth1,
  $etcd_s2s_proto  = 'http',    # XXX default ought to be https
  $etcd_c2s_ip     = '0.0.0.0',
  $etcd_c2s_proto  = 'http',    # XXX default ought to be https
  $etcd_listen_ip  = '0.0.0.0',
  $etcd_image      = 'quay.io/coreos/etcd',
  $etcd_extra      = [],        # extra arguments to etcd
  $tls_key_file    = "/etc/ssl/private/${::fqdn}_infra.key",
  $tls_ca_file     = '/etc/ssl/certs/infra.crt',
  $tls_cert_file   = "/etc/ssl/certs/${::fqdn}_infra.crt",
  $expose_ports    = true,
)
{
   include stdlib

   # Add brackets to bare IPv6 IP.
   $s2s_ip = $etcd_s2s_ip ? {
     /^[0-9a-fA-F:]+$/ => "[${etcd_s2s_ip}]",  # bare IPv6 address
     default           => $etcd_s2s_ip,        # IPv4 or hostname probably
   }

   # Add brackets to bare IPv6 IP.
   $c2s_ip = $etcd_c2s_ip ? {
     /^[0-9a-fA-F:]+$/ => "[${etcd_c2s_ip}]",  # bare IPv6 address
     default           => $etcd_c2s_ip,        # IPv4 or hostname probably
   }

   # Add brackets to bare IPv6 IP.
   $listen_ip = $etcd_listen_ip ? {
     /^[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}$/ => $etcd_listen_ip,  # IPv4
     /^[0-9a-fA-F:]+$/ => "[${etcd_listen_ip}]",
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
   $listen_c_url = "${etcd_c2s_proto}://${listen_ip}"
   $listen_s_url = "${etcd_s2s_proto}://${listen_ip}"
   if $proxy {
      $proxy_type = $proxy_readonly ? {
        true  => 'readonly',
        false => 'on',
      }
      $args = flatten([$common_args,
                       "--proxy $proxy_type",
                       "--listen-client-urls ${c2s_url}:4001,${c2s_url}:2379",
                       ])
   } else {
      $args = flatten([$common_args,
                       "--advertise-client-urls ${c2s_url}:2379",
                       "--listen-client-urls ${listen_c_url}:2379,${listen_c_url}:4001",
                       "--initial-advertise-peer-urls ${s2s_url}:2380",
                       "--listen-peer-urls ${listen_s_url}:2380",
                       "--peer-key-file ${tls_key_file}",
                       "--peer-ca-file ${tls_ca_file}",
                       "--peer-cert-file ${tls_cert_file}",
                       ])
   }

   $ports = $expose_ports ? {
     # XXX no way to listen to specific IP for now
     true => ['2380:2380',
              '2379:2379',
              "${::ipaddress_docker0}:4001:2379",
              ],
     false => []
   }

   sunet::docker_run { "etcd_${name}":
      image            => $etcd_image,
      imagetag         => $etcd_version,
      volumes          => ["/data/${name}:/data",
                           "${tls_key_file}:${tls_key_file}:ro",
                           "${tls_ca_file}:${tls_ca_file}:ro",
                           "${tls_cert_file}:${tls_cert_file}:ro",
                           ],
      command          => join($args," "),
      ports            => $ports,
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
         port => '4001',
      }
      ufw::allow { "allow-etcd-peer":
         ip   => $etcd_s2s_ip,
         port => '2380',
      }
      ufw::allow { "allow-etcd-client":
         ip   => $etcd_c2s_ip,
         port => '2379',
      }
   }
}
