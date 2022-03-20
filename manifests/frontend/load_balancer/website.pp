# New kind of website with one docker-compose setup per website
define sunet::frontend::load_balancer::website(
  String  $basedir,
  String  $confdir,
  String  $scriptdir,
  Hash    $config,
  Integer $api_port = 8080,
) {
  $instance  = $name
  $site_name = pick($config['site_name'], $instance)
  $monitor_group = pick($config['monitor_group'], 'default')

  if ! has_key($config, 'tls_certificate_bundle') {
    # Put suitable certificate path in $config['tls_certificate_bundle']
    if has_key($::tls_certificates, 'snakeoil') {
      $snakeoil = $::tls_certificates['snakeoil']['bundle']
    }
    if has_key($::tls_certificates, $site_name) {
      # Site name found in tls_certificates - good start
      $_tls_certificate_bundle = pick(
        $::tls_certificates[$site_name]['haproxy'],
        $::tls_certificates[$site_name]['certkey'],
        $::tls_certificates[$site_name]['infra_certkey'],
        $::tls_certificates[$site_name]['bundle'],
        $::tls_certificates[$site_name]['dehydrated_bundle'],
        'NOMATCH',
      )
      if $_tls_certificate_bundle != 'NOMATCH' {
        $tls_certificate_bundle = $_tls_certificate_bundle
      } else {
        $_site_certs = $::tls_certificates[$site_name]
        notice(join([
          "None of the certificates for site ${site_name} matched my list ",
          "(haproxy, certkey, infra_certkey, bundle, dehydrated_bundle): ${_site_certs}"
        ], ''))
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
    $tls_certificate_bundle = $config['tls_certificate_bundle']
    $config2 = $config
  }

  # Add IP and hostname of the host running the container - used to reach the
  # acme-c proxy in eduid
  $config3 = merge($config2, {
    'frontend_ip4' => $::ipaddress_default,
    'frontend_ip6' => $::ipaddress6_default,
    'frontend_fqdn' => $::fqdn,
  })

  $local_config = hiera_hash('sunet_frontend_local', undef)
  $config4 = deep_merge($config3, $local_config)
  ensure_resource('sunet::misc::create_dir', ["${confdir}/${instance}",
                                              "${confdir}/${instance}/certs",
                                              ], { owner => 'root', group => 'root', mode => '0700' })

  # copy $tls_certificate_bundle to the instance 'certs' directory to detect when it is updated
  # so the service can be restarted
  file {
    "${confdir}/${instance}/certs/tls_certificate_bundle.pem":
      source => $tls_certificate_bundle,
      notify => Sunet::Docker_compose["frontend-${instance}"],
  }

  # 'export' config to one YAML file per instance
  file {
    "${confdir}/${instance}/config.yml":
      ensure  => 'file',
      group   => 'sunetfrontend',
      mode    => '0640',
      force   => true,
      content => inline_template("# File created from Hiera by Puppet\n<%= @config4.to_yaml %>\n"),
      ;
  }

  if $::sunet_nftables_opt_in != 'yes' and ! ( $::operatingsystem == 'Ubuntu' and versioncmp($::operatingsystemrelease, '22.04') >= 0 ) {
    $_docker_ip = $::ipaddress_docker0
  } else {
    $_docker_ip = '172.16.0.2'  # TODO: Parameterise this somehow
  }

  # Parameters used in frontend/docker-compose_template.erb
  $dns                    = pick_default($config['dns'], undef)
  $extra_ports            = pick_default($config['extra_ports'], undef)
  $frontendtools_imagetag = pick($config['frontendtools_imagetag'], 'stable')
  $frontendtools_volumes  = pick($config['frontendtools_volumes'], false)
  $haproxy_image          = pick($config['haproxy_image'], 'docker.sunet.se/library/haproxy')
  $haproxy_imagetag       = pick($config['haproxy_imagetag'], 'stable')
  $haproxy_volumes        = pick($config['haproxy_volumes'], false)
  $statsd_enabled         = pick($config['statsd_enabled'], true)
  $statsd_host            = pick($_docker_ip, $::ipaddress)
  $varnish_config         = pick($config['varnish_config'], '/opt/frontend/config/common/default.vcl')
  $varnish_enabled        = pick($config['varnish_enabled'], false)
  $varnish_image          = pick($config['varnish_image'], 'docker.sunet.se/library/varnish')
  $varnish_imagetag       = pick($config['varnish_imagetag'], 'stable')
  $varnish_storage        = pick($config['varnish_storage'], 'malloc,100M')

  ensure_resource('file', '/usr/local/bin/start-frontend', {
    ensure  => 'file',
    mode    => '0755',
    content => template('sunet/frontend/start-frontend.erb'),
  })

  ensure_resource('file', "${scriptdir}/haproxy-start.sh", {
    ensure  => 'file',
    mode    => '0755',
    content => template('sunet/frontend/haproxy-start.sh.erb'),
  })

  ensure_resource('file', "${scriptdir}/configure-container-network", {
    ensure  => 'file',
    mode    => '0755',
    content => template('sunet/frontend/configure-container-network.erb'),
  })

  ensure_resource('file', "${scriptdir}/frontend-config", {
    ensure  => 'file',
    mode    => '0755',
    content => template('sunet/frontend/frontend-config.erb'),
  })

  sunet::docker_compose { "frontend-${instance}":
    content          => template('sunet/frontend/docker-compose_template.erb'),
    service_prefix   => 'frontend',
    service_name     => $instance,
    compose_dir      => $confdir,
    compose_filename => 'docker-compose.yml',
    description      => "SUNET frontend instance ${instance} (site ${site_name})",
    start_command    => "/usr/local/bin/start-frontend ${basedir} ${name} ${confdir}/${instance}/docker-compose.yml",
  }

  if $::sunet_nftables_opt_in != 'yes' and ! ( $::operatingsystem == 'Ubuntu' and versioncmp($::operatingsystemrelease, '22.04') >= 0 ) {
    # OLD way
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

    # old, traffic was routed to "br-foo"
    exec { "workaround_allow_forwarding_to_${instance}":
      command => "/usr/sbin/ufw route allow out on br-${instance}",
    }
    # new, traffic is routed into "to_foo" which is connected to the "br-foo" (which resides in another network ns)
    exec { "workaround_allow_forwarding_to_${instance}_2":
      command => "/usr/sbin/ufw route allow out on to_${instance}",
    }
  } else {
    # NEW way, configure forwarding and IPv6 NAT (for haproxy to reach ipv6-only backends) using
    # an nftables drop-in file.

    $frontend_ips = get_all_frontend_ips($config)

    # Variables used in template
    #
    $tcp_dport = sunet::format_nft_set('dport', pick($config['allow_ports'], []))
    $frontend_ips_v4 = sunet::format_nft_set('', filter($frontend_ips) | $this | { is_ipaddr($this, 4) })
    $frontend_ips_v6 = sunet::format_nft_set('', filter($frontend_ips) | $this | { is_ipaddr($this, 6) })
    #
    ensure_resource('file', "/etc/nftables/conf.d/700-frontend-${instance}.nft", {
      ensure  => 'file',
      mode    => '0400',
      content => template('sunet/frontend/700-frontend-instance_nftables.nft.erb'),
      notify  => Service['nftables'],
    })
  }

  if has_key($config, 'letsencrypt_server') and $config['letsencrypt_server'] != $::fqdn {
    sunet::dehydrated::client_define { $name :
      domain        => $name,
      server        => $config['letsencrypt_server'],
      check_cert    => false,
      ssh_id        => 'acme_c',  # use shared key for all certs (Hiera key acme_c_ssh_key)
      single_domain => false,
    }
  }

  # Set up the API for this instance
  each($config['backends']) | $k, $v | {
    # k should be a backend name (like 'default') and v a hash with it's backends:
    #   $v = {host.example.org => {ips => [192.0.2.1]}}
    if is_hash($v) {
      each($v) | $name, $params | {
        sunet::frontend::api::instance { "api_${instance}_${k}_${name}":
          site_name   => $site_name,
          backend_ips => $params['ips'],
          api_port    => $api_port,
        }
      }
    }
  }
}

# Get a list of all the instances frontend addresses
function get_all_frontend_ips(
  Hash[String, Any] $config,
) >> Array[String] {
  if ! has_key($config, 'frontends') {
    fail('Website config contains no frontends section')
  }
  $all_ips = map($config['frontends']) | $frontend_fqdn, $v | {
    # k should be a frontend FQDN and $v a hash with ips in it:
    #   $v = {ips => [192.0.2.1]}}
    (is_hash($v) and has_key($v, 'ips')) ? {
      true  => $v['ips'],
      false => []
    }
  }

  $uniq = flatten($all_ips).unique
  $uniq
}
