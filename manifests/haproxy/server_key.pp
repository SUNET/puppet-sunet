# Create TLS certificate bundles the way haproxy likes them
define sunet::haproxy::server_key (
  String $server_name,
  String $hiera_key,
  String $ssl_dir              = '/etc/ssl',
  Optional[String] $cert_chain = undef,
) {
  $server_key         = "${ssl_dir}/${server_name}.key"
  $server_cert        = "${ssl_dir}/${server_name}.pem"
  $server_cert_chain  = $cert_chain ? {
    undef   => "${ssl_dir}/cert-chain.pem",
    default => $cert_chain,
  }

  sunet::misc::create_key_file { $server_key :
    hiera_key => $hiera_key,
    group     => 'ssl-cert',
  }

  $haproxy_bundle = "${ssl_dir}/${server_name}_haproxy.crt"
  file {
    $haproxy_bundle:
      ensure => 'present',
      owner  => 'root',
      group  => 'ssl-cert',
      mode   => '0640',
      ;
  }
  exec {"${server_name}_fix_haproxy_bundle":
    path    => ['/usr/bin', '/bin'],
    command => "test -f ${server_key} && test -f ${server_cert} && test -f ${server_cert_chain} && cat ${server_key} ${server_cert} ${server_cert_chain} > ${haproxy_bundle}",
    unless  => "test -s ${haproxy_bundle}",
    require => [Sunet::Misc::Create_key_file[$server_key],
                File[$haproxy_bundle],
                ],
  }
}
