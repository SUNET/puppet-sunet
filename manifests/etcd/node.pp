# etcd node
class sunet::etcd::node(
  String           $docker_tag,
  String           $service_name = 'etcd',
  Optional[String] $disco_url       = undef,
  Optional[String] $initial_cluster = undef,
  Optional[String] $discovery_srv   = undef,  # DNS SRV record for cluster node discovery
  Boolean          $proxy           = true,
  Boolean          $proxy_readonly  = false,
  String           $etcd_s2s_ip     = $::fqdn,
  String           $etcd_s2s_proto  = 'https',
  String           $etcd_c2s_ip     = $::fqdn,
  String           $etcd_c2s_proto  = 'https',
  String           $etcd_listen_ip  = '0.0.0.0',
  String           $docker_image    = 'gcr.io/etcd-development/etcd',
  String           $docker_net      = 'docker',
  Array[String]    $etcd_extra      = [],        # extra arguments to etcd
  Optional[String] $tls_key_file    = undef,
  Optional[String] $tls_ca_file     = undef,
  Optional[String] $tls_cert_file   = undef,
  Boolean          $expose_ports    = true,
  String           $expose_port_pre = '',
  Array[String]    $allow_clients   = ['any'],
  Array[String]    $allow_peers     = [],
)
{
  include stdlib

  # Add brackets to bare IPv6 IP.
  $s2s_ip = is_ipaddr($etcd_s2s_ip, 6) ? {
    true  => "[${etcd_s2s_ip}]",
    false => $etcd_s2s_ip,
  }
  $c2s_ip = is_ipaddr($etcd_c2s_ip, 6) ? {
    true  => "[${etcd_c2s_ip}]",
    false => $etcd_c2s_ip,
  }
  $listen_ip = enclose_ipv6([$etcd_listen_ip])[0]

  # Use infra-cert per default if cert/key/ca file not supplied
  $_tls_cert_file = $tls_cert_file ? {
    undef => $::tls_certificates[$::fqdn]['infra_cert'],
    default => $tls_cert_file,
  }
  $_tls_key_file = $tls_key_file ? {
    undef => $::tls_certificates[$::fqdn]['infra_key'],
    default => $tls_key_file,
  }
  $_tls_ca_file = pick($tls_ca_file, '/etc/ssl/certs/infra.crt')

  # Create simple wrapper to run ectdctl in a new docker container with all the right parameters
  file {
    '/usr/local/bin/etcdctl':
      owner   => 'root',
      group   => 'root',
      mode    => '0700',
      content => inline_template(@("END"/n))
      #!/bin/sh
      # script created by Puppet

      exec docker run --rm -it \
      -v ${_tls_cert_file}:${_tls_cert_file}:ro \
      -v ${_tls_key_file}:${_tls_key_file}:ro \
      -v ${_tls_ca_file}:${_tls_ca_file}:ro \
      --entrypoint /usr/local/bin/etcdctl \
      ${docker_image}:${docker_tag} \
      --discovery-srv ${discovery_srv} \
      --key-file ${_tls_key_file} \
      --ca-file ${_tls_ca_file} \
      --cert-file ${_tls_cert_file} $*
      |END
      ;
  }

  sunet::misc::create_dir { "/data/${service_name}/${::hostname}":
    owner => 'root',
    group => 'root',
    mode => '0700',
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
  $common_args = ['/usr/local/bin/etcd',
                  $disco_args,
                  "--name ${::hostname}",
                  '--data-dir /data',
                  "--key-file ${_tls_key_file}",
                  "--ca-file ${_tls_ca_file}",
                  "--cert-file ${_tls_cert_file}",
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
                     "--peer-key-file ${_tls_key_file}",
                     "--peer-ca-file ${_tls_ca_file}",
                     "--peer-cert-file ${_tls_cert_file}",
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
    image    => $docker_image,
    imagetag => $docker_tag,
    volumes  => ["/data/${service_name}:/data",
                 "${_tls_key_file}:${_tls_key_file}:ro",
                 "${_tls_ca_file}:${_tls_ca_file}:ro",
                 "${_tls_cert_file}:${_tls_cert_file}:ro",
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
