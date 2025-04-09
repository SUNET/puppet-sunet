# etcd version 3 node
class sunet::etcd::node(
  String           $docker_tag         = 'latest',
  String           $service_name       = 'etcd',
  Optional[String] $disco_url          = undef,
  Array[String]    $cluster_nodes      = [$facts['networking']['fqdn']],
  Optional[String] $discovery_srv      = undef,  # DNS SRV record for cluster node discovery
  Enum['on', 'readonly', 'off'] $proxy = 'off',
  String           $s2s_ip_or_host     = $facts['networking']['fqdn'],
  String           $c2s_ip_or_host     = $facts['networking']['fqdn'],
  Enum['https', 'http'] $c2s_proto     = 'https',
  String           $etcd_listen_ip     = '0.0.0.0',
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
  String           $base_dir           = '/opt',
  Boolean          $enable_v2          = false,
)
{
  include stdlib

  # Add brackets to bare IPv6 IP.
  $s2s_ip = is_ipaddr($s2s_ip_or_host, 6) ? {
    true  => "[${s2s_ip_or_host}]",
    false => $s2s_ip_or_host,
  }
  $c2s_ip = is_ipaddr($c2s_ip_or_host, 6) ? {
    true  => "[${c2s_ip_or_host}]",
    false => $c2s_ip_or_host,
  }
  $listen_ip = enclose_ipv6([$etcd_listen_ip])[0]

  # Use infra-cert per default if cert/key/ca file not supplied
  $cert_file = $tls_cert_file ? {
    undef => $facts['tls_certificates'][$::fqdn]['infra_cert'],
    default => $tls_cert_file,
  }
  $key_file = $tls_key_file ? {
    undef => $facts['tls_certificates'][$::fqdn]['infra_key'],
    default => $tls_key_file,
  }
  $trusted_ca_file = pick($tls_ca_file, '/etc/ssl/certs/infra.crt')

  # variables used in etcd.conf.yml.erb and ectdctl.erb
  $listen_peer_urls = ["https://${listen_ip}:2380"]
  $listen_client_urls = ["${c2s_proto}://${listen_ip}:2379"]
  $initial_advertise_peer_urls = ["https://${s2s_ip}:2380"]
  $advertise_client_urls = ["${c2s_proto}://${c2s_ip}:2379"]
  $initial_cluster = $cluster_nodes.map | $this | {
    $this_name = split($this, '\.')[0]
    sprintf('%s=https://%s:2380', $this_name, $this)
  }

  # Create simple wrapper to run ectdctl in a new docker container with all the right parameters
  file {
    '/usr/local/bin/etcdctl':
      owner   => 'root',
      group   => 'root',
      mode    => '0750',
      content => template('sunet/etcd/etcdctl.erb'),
      ;
  }


  sunet::misc::create_dir { "${base_dir}/${service_name}/data":
    owner => 'root',
    group => 'root',
    mode  => '0700',
  }

  -> sunet::misc::create_cfgfile { "${base_dir}/${service_name}/etcd.conf.yml":
    content => template('sunet/etcd/etcd.conf.yml.erb'),
    group   => 'root',
    force   => true,
    notify  => [Sunet::Docker_run[$service_name]],
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
    volumes  => ["${base_dir}/${service_name}/data:/data",
                "${base_dir}/${service_name}/etcd.conf.yml:${base_dir}/${service_name}/etcd.conf.yml:ro",
                "${cert_file}:${cert_file}:ro",
                "${key_file}:${key_file}:ro",
                "${trusted_ca_file}:${trusted_ca_file}:ro",
                ],
    command  => "/usr/local/bin/etcd --config-file ${base_dir}/${service_name}/etcd.conf.yml",
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
