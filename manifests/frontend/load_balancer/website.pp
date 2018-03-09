# New kind of website with one docker-compose setup per website
define sunet::frontend::load_balancer::website(
  String $basedir,
  String $confdir,
  Hash   $config
) {
  if ! has_key('tls_certificate_bundle', $config) {
    # Put suitable certificate path in $config['tls_certificate_bundle']
    if has_key($tls_certificates, 'snakeoil') {
      $snakeoil = $tls_certificates['snakeoil']['bundle']
    }
    if has_key($tls_certificates, $name) {
      # Site name found in tls_certificates - good start
      $_tls_certificate_bundle = pick(
        $tls_certificates[$name]['haproxy'],
        $tls_certificates[$name]['certkey'],
        $tls_certificates[$name]['infra_certkey'],
        $tls_certificates[$name]['bundle'],
        $tls_certificates[$name]['dehydrated_bundle'],
        'NOMATCH',
      )
      if $_tls_certificate_bundle != 'NOMATCH' {
        $tls_certificate_bundle = $_tls_certificate_bundle
      } else {
        $_site_certs = $tls_certificates[$name]
        notice("None of the certificates for site ${name} matched my list (haproxy, certkey, infra_certkey, bundle): $_site_certs")
        if $snakeoil {
          $tls_certificate_bundle = $snakeoil
        }
      }
    } elsif $snakeoil {
      $tls_certificate_bundle = $snakeoil
    }

    if $snakeoil and $tls_certificate_bundle == $snakeoil {
      notice("Using snakeoil certificate for site ${name}")
    }
    $config2 = merge($config, {'tls_certificate_bundle' => $tls_certificate_bundle})
  } else {
    $config2 = $config
  }

  # 'export' config to a file
  file {
    "${confdir}/${name}":
      ensure  => 'directory',
      group   => 'sunetfrontend',
      mode    => '0750',
      ;
    "${confdir}/${name}/config.yml":
      ensure  => 'file',
      group   => 'sunetfrontend',
      mode    => '0640',
      content => inline_template("# File created from Hiera by Puppet\n<%= @config2.to_yaml %>\n"),
      ;
  }

  # Parameters used in frontend/docker-compose_template.erb
  $site_name        = $name
  $instance         = pick($config['instance'], $site_name)
  $haproxy_image    = pick($config['haproxy_image'], 'docker.sunet.se/library/haproxy')
  $haproxy_imagetag = pick($config['haproxy_imagetag'], 'stable')

  sunet::docker_compose { "frontend-${instance}":
    content        => template('sunet/frontend/docker-compose_template.erb'),
    service_prefix => 'frontend',
    service_name   => $instance,
    compose_dir    => "${confdir}/${name}/compose",
    description    => "SUNET frontend setup for ${instance}",
    service_extras => ["ExecStartPost=-${basedir}/scripts/container-network-config ${name}"],
  }
}
