# etcd node
class sunet::etcd::node(
  String $etcd_version,
  String $service_name = 'etcd',
  $disco_url       = undef,
  $initial_cluster = undef,
  $discovery_srv   = undef,
  $proxy           = true,
  $proxy_readonly  = false,
  $docker_net      = 'docker',
  $etcd_s2s_ip     = $::ipaddress_eth1,
  $etcd_s2s_proto  = 'https',
  $etcd_c2s_ip     = '0.0.0.0',
  $etcd_c2s_proto  = 'https',
  $etcd_listen_ip  = '0.0.0.0',
  $etcd_image      = 'gcr.io/etcd-development/etcd',
  $etcd_extra      = [],        # extra arguments to etcd
  $tls_key_file    = "/etc/ssl/private/${::fqdn}_infra.key",
  $tls_ca_file     = '/etc/ssl/certs/infra.crt',
  $tls_cert_file   = "/etc/ssl/${::fqdn}_infra.pem",
  $expose_ports    = true,
  $expose_port_pre = '',
  $allow_clients   = ['any'],
  $allow_peers     = [],
)
{
  include stdlib

  # Add brackets to bare IPv6 IP.
  $s2s_ip = enclose_ipv6([$etcd_s2s_ip])[0]
  $c2s_ip = enclose_ipv6([$etcd_c2s_ip])[0]
  $listen_ip = enclose_ipv6([$listen_ip])[0]

  sunet::misc::create_dir { "/data/${service_name}/${::hostname}": owner => 'root', group => 'root', mode => '0700' }

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
  $common_args = ['/usr/local/bin/etcd',
                  $disco_args,
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
                     "--proxy ${proxy_type}",
                     "--listen-client-urls ${c2s_url}:2379",
                     ])
  } else {
    $args = flatten([$common_args,
                     "--advertise-client-urls ${c2s_url}:2379",
                     "--listen-client-urls ${listen_c_url}:2379",
                     "--initial-advertise-peer-urls ${s2s_url}:2380",
                     "--listen-peer-urls ${listen_s_url}:2380",
                     "--peer-key-file ${tls_key_file}",
                     "--peer-ca-file ${tls_ca_file}",
                     "--peer-cert-file ${tls_cert_file}",
                     ])
  }

  $ports = $expose_ports ? {
    true => ["${expose_port_pre}:2380:2380",
             "${expose_port_pre}:2379:2379",
             "${::ipaddress_docker0}:4001:2379",
             ],
    false => []
  }

  sunet::docker_run { $service_name:
    image    => $etcd_image,
    imagetag => $etcd_version,
    volumes  => ["/data/${service_name}:/data",
                 "${tls_key_file}:${tls_key_file}:ro",
                 "${tls_ca_file}:${tls_ca_file}:ro",
                 "${tls_cert_file}:${tls_cert_file}:ro",
                 ],
    command  => join($args, ' '),
    ports    => $ports,
    net      => $docker_net,
  }
  if ! $proxy {
    sunet::misc::ufw_allow { 'allow-etcd-peer':
      from => $allow_peers,
      port => '2380',
    }
    sunet::misc::ufw_allow { 'allow-etcd-client':
      from => $allow_clients,
      port => '2379',
    }
  }
}
