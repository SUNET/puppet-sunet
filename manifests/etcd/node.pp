# etcd version 3 node
class sunet::etcd::node(
  String           $docker_tag,
  String           $service_name       = 'etcd',
  Optional[String] $disco_url          = undef,
  Array[String]    $cluster_nodes      = [$::fqdn],
  Optional[String] $discovery_srv      = undef,  # DNS SRV record for cluster node discovery
  Enum['on', 'readonly', 'off'] $proxy = 'off',
  String           $s2s_ip             = $::fqdn,
  String           $s2s_proto          = 'https',
  String           $c2s_ip             = $::fqdn,
  String           $c2s_proto          = 'https',
  String           $listen_ip          = '0.0.0.0',
  String           $docker_image       = 'gcr.io/etcd-development/etcd',
  String           $docker_net         = 'docker',
  Array[String]    $etcd_extra         = [],        # extra arguments to etcd
  Optional[String] $tls_key_file       = undef,
  Optional[String] $tls_ca_file        = undef,
  Optional[String] $tls_cert_file      = undef,
  Boolean          $expose_ports       = true,
  String           $expose_port_pre    = '',   # string prepended to ports (e.g. "127.0.0.1:")
  Array[String]    $allow_clients      = ['any'],
  Array[String]    $allow_peers        = [],
  Boolean          $client_cert_auth   = true,  # Enable TLS client certificate authentication - turn CN into username
  String           $base_dir           = '/local',
  Boolean          $enable_v2          = false,
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
          -e 'ETCDCTL_API=3' \
          ${docker_image}:${docker_tag} \
          --endpoints https://${fqdn}:2380 \
          --insecure-discovery \
          --key ${_tls_key_file} \
          --cacert ${_tls_ca_file} \
          --cert ${_tls_cert_file} $*
      |END
      ;
  }

  sunet::misc::create_dir { "${base_dir}/${service_name}/data/${::hostname}":
    owner => 'root',
    group => 'root',
    mode => '0700',
  }

  # variables used in etcd.conf.yml.erb
  $listen_peer_urls = ["${s2s_proto}://${listen_ip}:2380"]
  $listen_client_urls = ["${c2s_proto}://${listen_ip}:2379"]
  $initial_advertise_peer_urls = ["${s2s_proto}://${s2s_ip}:2380"]
  $advertise_client_urls = ["${c2s_proto}://${c2s_ip}:2379"]
  $initial_cluster = $cluster_nodes.map | $this | {
    $this_name = split($this, '.')[0]
    sprintf('%s=%s://%s:2380', $this_name, $s2s_proto, $this)
  }

  sunet::misc::create_cfgfile { "${basedir}/${service_name}/etcd.conf.yml":
    content => template('sunet/etcd/etcd.conf.yml.erb'),
    group   => 'root',
    force   => true,
  }
  $ports = $expose_ports ? {
    true => ["${expose_port_pre}:2380:2380",
             "${expose_port_pre}:2379:2379",
             ],
    false => []
  }

  sunet::docker_run { $service_name:
    image    => $docker_image,
    imagetag => $docker_tag,
    volumes  => ["/${base_dir}/${service_name}/data:/data",
                 "${basedir}/${service_name}/etcd.conf.yml:${basedir}/${service_name}/etcd.conf.yml:ro",
                 "${_tls_key_file}:${_tls_key_file}:ro",
                 "${_tls_ca_file}:${_tls_ca_file}:ro",
                 "${_tls_cert_file}:${_tls_cert_file}:ro",
                 ],
    command  => "/usr/local/bin/etcd --config-file ${basedir}/${service_name}/etcd.conf.yml",
    ports    => $ports,
    net      => $docker_net,
  }
  sunet::misc::ufw_allow { 'allow-etcd-peer':
    from => $allow_peers,
    port => '2380',
  }
  sunet::misc::ufw_allow { 'allow-etcd-client':
    from => $allow_clients,
    port => '2379',
  }
}
