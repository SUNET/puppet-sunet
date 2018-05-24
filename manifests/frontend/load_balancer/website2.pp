# New kind of website with one docker-compose setup per website
define sunet::frontend::load_balancer::website2(
  String  $basedir,
  String  $confdir,
  Hash    $config,
  Integer $api_port = 8080,
) {
  $instance  = $name
  $site_name = pick($config['site_name'], $instance)

  if ! has_key($config, 'tls_certificate_bundle') {
    # Put suitable certificate path in $config['tls_certificate_bundle']
    if has_key($tls_certificates, 'snakeoil') {
      $snakeoil = $tls_certificates['snakeoil']['bundle']
    }
    if has_key($tls_certificates, $site_name) {
      # Site name found in tls_certificates - good start
      $_tls_certificate_bundle = pick(
        $tls_certificates[$site_name]['haproxy'],
        $tls_certificates[$site_name]['certkey'],
        $tls_certificates[$site_name]['infra_certkey'],
        $tls_certificates[$site_name]['bundle'],
        $tls_certificates[$site_name]['dehydrated_bundle'],
        'NOMATCH',
      )
      if $_tls_certificate_bundle != 'NOMATCH' {
        $tls_certificate_bundle = $_tls_certificate_bundle
      } else {
        $_site_certs = $tls_certificates[$site_name]
        notice("None of the certificates for site ${site_name} matched my list (haproxy, certkey, infra_certkey, bundle, dehydrated_bundle): $_site_certs")
        if $snakeoil {
          $tls_certificate_bundle = $snakeoil
        }
      }
    } elsif $snakeoil {
      $tls_certificate_bundle = $snakeoil
    }

    if $snakeoil and $tls_certificate_bundle == $snakeoil {
      notice("Using snakeoil certificate for instance ${instance} (site ${site_name})")
    }
    $config2 = merge($config, {'tls_certificate_bundle' => $tls_certificate_bundle})
  } else {
    $config2 = $config
  }

  ensure_resource('sunet::misc::create_dir', ["${confdir}/${instance}"], { owner => 'root', group => 'root', mode => '0700' })

  # 'export' config to one YAML file per instance
  file {
    "${confdir}/${instance}/config.yml":
      ensure  => 'file',
      group   => 'sunetfrontend',
      mode    => '0640',
      force   => true,
      content => inline_template("# File created from Hiera by Puppet\n<%= @config2.to_yaml %>\n"),
      ;
  }

  # Parameters used in frontend/docker-compose_template.erb
  $haproxy_image    = pick($config['haproxy_image'], 'docker.sunet.se/library/haproxy')
  $haproxy_imagetag = pick($config['haproxy_imagetag'], 'stable')
  $varnish_image    = pick($config['varnish_image'], 'docker.sunet.se/library/varnish')
  $varnish_imagetag = pick($config['varnish_imagetag'], 'stable')
  $varnish_config   = pick($config['varnish_config'], '/opt/frontend/config/common/default.vcl')
  $varnish_enabled  = pick($config['varnish_enabled'], false)
  $varnish_storage  = pick($config['varnish_storage'], 'malloc,100M')

  sunet::docker_compose { "frontend-${instance}":
    content          => template('sunet/frontend/docker-compose_template.erb'),
    service_prefix   => 'frontend',
    service_name     => $instance,
    compose_dir      => $confdir,
    compose_filename => 'docker-compose.yml',
    description      => "SUNET frontend instance ${instance} (site ${site_name})",
    service_extras   => ["ExecStartPost=-${basedir}/scripts/configure-container-network ${name}"],
  }

  each($config['backends']) | $k, $v | {
    # k should be a backend name (like 'default') and v a hash with it's backends:
    #   $v = {host.example.org => {ips => [192.0.2.1]}}
    if is_hash($v) {
      each($v) | $name, $params | {
        sunet::misc::ufw_allow { "allow_backends_to_api_${instance}_${k}_${name}":
          from => $params['ips'],
          port => $api_port,
        }
      }
    }
  }

  if has_key($config, 'allow_ports') {
    each($config['frontends']) | $k, $v | {
      # k should be a frontend FQDN and $v a hash with ips in it:
      #   $v = {ips => [192.0.2.1]}}
      if is_hash($v) and has_key($v, 'ips') {
        sunet::misc::ufw_allow { "allow_ports_to_${instance}_frontend_${k}":
          from => 'any',
          to   => $v['ips'],
          port => $config['allow_ports'],
        }
      }
    }
  }
  exec { "workaround_allow_forwarding_to_${instance}":
    command => "/usr/sbin/ufw route allow out on br-${instance}",
  }

  if has_key($config, 'letsencrypt_server') and $config['letsencrypt_server'] != $::fqdn {
    sunet::dehydrated::client_define { $name :
      domain        => $name,
      server        => $config['letsencrypt_server'],
      ssh_id        => 'acme_c',  # use shared key for all certs (Hiera key acme_c_ssh_key)
      single_domain => false,
    }
  }

  # Create backend directory for this website so that the sunetfrontend-api will
  # accept register requests from the servers
  file {
    "${basedir}/api/backends/${site_name}":
      ensure => 'directory',
      group  => 'sunetfrontend',
      mode   => '0770',
      ;
  }
}
