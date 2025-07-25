# New kind of website with one docker-compose setup per website
define sunet::lb::load_balancer::website(
  String  $basedir,
  String  $confdir,
  String  $scriptdir,
  Hash    $config,
  String  $interface = 'eth0',
  Integer $api_port = 8080,
) {
  $instance  = $name
  if length($instance) > 12 {
    notice("Instance name: ${instance} is longer than 12 characters and will not work in docker bridge networking, please rename instance.")
  }
  $site_name = pick($config['site_name'], $instance)
  $monitor_group = pick($config['monitor_group'], 'default')
  $haproxy_template_dir = lookup('haproxy_template_dir', undef, undef, $instance)

  # Figure out what certificate to pass to the haproxy container
  if 'tls_certificate_bundle' in $config {
    $tls_certificate_bundle = $config['tls_certificate_bundle']
  } else {
    if 'snakeoil' in $facts['tls_certificates'] {
      $snakeoil = $facts['tls_certificates']['snakeoil']['bundle']
    }
    if $site_name in $facts['tls_certificates'] {
      # Site name found in tls_certificates - good start
      $_tls_certificate_bundle = pick(
        $facts['tls_certificates'][$site_name]['haproxy'],
        $facts['tls_certificates'][$site_name]['certkey'],
        $facts['tls_certificates'][$site_name]['infra_certkey'],
        $facts['tls_certificates'][$site_name]['bundle'],
        $facts['tls_certificates'][$site_name]['dehydrated_bundle'],
        'NOMATCH',
      )
      if $_tls_certificate_bundle != 'NOMATCH' {
        $tls_certificate_bundle = $_tls_certificate_bundle
      } else {
        $_site_certs = $facts['tls_certificates'][$site_name]
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
  }

  if $tls_certificate_bundle {
    $tls_certificate_bundle_on_host = "${confdir}/${instance}/certs/tls_certificate_bundle.pem"
    $tls_certificate_bundle_in_container = '/opt/frontend/certs/tls_certificate_bundle.pem'
    # The certificate to use has been identified. It will be copied to $tls_certificate_bundle_on_host below,
    # but for file access reasons (and convenience) it is mounted at $tls_certificate_bundle_in_container,
    # and that path needs to reach the haproxy config template, so put (update) it in the config.
    $config2 = merge($config, {'tls_certificate_bundle' => $tls_certificate_bundle_in_container})
  } else {
    $config2 = $config
  }

  if $::facts['sunet_nftables_enabled'] != 'yes' {
    # OLD setup
    $_docker_ip = $facts['networking']['interfaces']['docker0']['ip']
    # On old setups, containers can't reach IPv6 only ACME-C backend directly, but have to go through
    # a proxy process (always-https) running on the frontend host itself.
    $_letsencrypt_override_address = $facts['networking']['ip']
  } else {
    # NEW setup with Docker in namespace
    $_docker_ip = '172.16.0.2'  # TODO: Parameterise this somehow
    $_letsencrypt_override_address = undef
  }

  # Add IP and hostname of the host running the container - used to reach the
  # acme-c proxy in eduid
  $config3a = merge($config2, {
    'frontend_ip4' => $facts['networking']['ip'],
    'frontend_ip6' => $facts['networking']['ip6'],
    'frontend_fqdn' => $facts['networking']['fqdn'],
  })

  if $_letsencrypt_override_address {
    $config3 = merge($config3a, {
      'letsencrypt_override_address' => $_letsencrypt_override_address,
    })
  } else {
    $config3 = $config3a
  }

  # This group is created by the exabgp package, but Puppet requires this before create_dir below
  ensure_resource('group', 'exabgp', {ensure => 'present'})

  $local_config = hiera_hash('sunet_frontend_local', undef)
  $config4 = deep_merge($config3, $local_config)
  # Setup directory where the 'config' container will read configuration data for this instance
  ensure_resource('sunet::misc::create_dir', ["${confdir}/${instance}",
                                              ], { owner => 'root', group => 'fe-config', mode => '0750' })
  # Setup directory where the 'monitor' container will write files read by the exabgp monitor script
  ensure_resource('sunet::misc::create_dir', ["${basedir}/monitor/${instance}",
                                              ], { owner => 'fe-monitor', group => 'exabgp', mode => '2750' })
  # Setup certificates directory for haproxy
  ensure_resource('sunet::misc::create_dir', ["${confdir}/${instance}/certs",
                                              ], { owner => 'root', group => 'haproxy', mode => '0750' })

  if $tls_certificate_bundle {
    # copy $tls_certificate_bundle to the instance 'certs' directory to detect when it is updated
    # so the service can be restarted
    file {
      $tls_certificate_bundle_on_host:
        owner  => 'root',
        group  => 'haproxy',
        mode   => '0640',
        source => $tls_certificate_bundle,
        notify => Sunet::Docker_compose["frontend-${instance}"],
    }
  }

  # 'export' config to one YAML file per instance
  # Both the config and monitor containers need to be able to read this file, but Docker will only allow
  # a single gid on the process, so the file needs to be world readable :/.
  file {
    "${confdir}/${instance}/config.yml":
      ensure  => 'file',
      group   => 'fe-config',
      mode    => '0644',
      force   => true,
      content => inline_template("# File created from Hiera by Puppet\n<%= @config4.to_yaml %>\n"),
      ;
  }

  # Parameters used in frontend/docker-compose_template.erb
  $allow_ports            = pick_default($config['allow_ports'], [])
  $stats_port             = pick_default($config['stats_port'], '')
  $dns                    = pick_default($config['dns'], [])
  $exposed_ports          = pick_default($config['exposed_ports'], [80, 443])
  $frontendtools_image    = pick($config['frontendtools_image'], 'docker.sunet.se/frontend/frontend-tools')
  $frontendtools_imagetag = pick($config['frontendtools_imagetag'], 'stable')
  $frontendtools_volumes  = pick($config['frontendtools_volumes'], false)
  $haproxy_image          = pick($config['haproxy_image'], 'docker.sunet.se/library/haproxy')
  $haproxy_imagetag       = pick($config['haproxy_imagetag'], 'stable')
  $haproxy_volumes        = pick($config['haproxy_volumes'], false)
  $multinode_port         = pick_default($config['multinode_port'], false)
  $statsd_enabled         = pick($config['statsd_enabled'], true)
  $statsd_host            = pick($_docker_ip, $facts['networking']['ip'])
  $varnish_config         = pick($config['varnish_config'], '/opt/frontend/config/common/default.vcl')
  $varnish_enabled        = pick($config['varnish_enabled'], false)
  $varnish_image          = pick($config['varnish_image'], 'docker.sunet.se/library/varnish')
  $varnish_imagetag       = pick($config['varnish_imagetag'], 'stable')
  $varnish_storage        = pick($config['varnish_storage'], 'malloc,100M')

  ensure_resource('file', '/usr/local/bin/start-frontend', {
    ensure  => 'file',
    mode    => '0755',
    content => template('sunet/lb/start-frontend.erb'),
  })

  ensure_resource('file', "${scriptdir}/haproxy-start.sh", {
    ensure  => 'file',
    mode    => '0755',
    content => template('sunet/lb/haproxy-start.sh.erb'),
  })

  ensure_resource('file', "${scriptdir}/configure-container-network", {
    ensure  => 'file',
    mode    => '0755',
    content => template('sunet/lb/configure-container-network.erb'),
  })

  ensure_resource('file', "${scriptdir}/frontend-config", {
    ensure  => 'file',
    mode    => '0755',
    content => template('sunet/lb/frontend-config.erb'),
  })

  sunet::docker_compose { "frontend-${instance}":
    content          => template('sunet/lb/docker-compose_template.erb'),
    service_prefix   => 'frontend',
    service_name     => $instance,
    compose_dir      => "${basedir}/compose",
    compose_filename => 'docker-compose.yml',
    description      => "SUNET frontend instance ${instance} (site ${site_name})",
    start_command    => "/usr/local/bin/start-frontend ${basedir} ${name} ${basedir}/compose/${instance}/docker-compose.yml",
  }

  if $::facts['sunet_nftables_enabled'] != 'yes' {
    # OLD way
    if 'allow_ports' in $config {
      each($config['frontends']) | $k, $v | {
        # k should be a frontend FQDN and $v a hash with ips in it:
        #   $v = {ips => [192.0.2.1]}}
        if $v =~ Hash and 'ips' in $v {
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

    $frontend_ips = sunet::lb::load_balancer::get_all_frontend_ips($config)

    # Variables used in template
    #
    $saddr = sunet::format_nft_set('saddr', pick($config['allow_ips'], 'any'))
    if $config['allow_ips'] {
      $saddr_v4 = sunet::format_nft_set('saddr', filter($config['allow_ips']) | $this | { is_ipaddr($this, 4) })
      $saddr_v6 = sunet::format_nft_set('saddr', filter($config['allow_ips']) | $this | { is_ipaddr($this, 6) })
    }

    $tcp_dport = sunet::format_nft_set('dport', pick($config['allow_ports'], []))
    $frontend_ips_v4 = sunet::format_nft_set('', filter($frontend_ips) | $this | { is_ipaddr($this, 4) })
    $frontend_ips_v6 = sunet::format_nft_set('', filter($frontend_ips) | $this | { is_ipaddr($this, 6) })
    $external_interface = pick($config['external_interface'], $::facts['interface_default'], $interface)

    if $stats_port != '' {
      $stats_dport = sunet::format_nft_set('dport', $stats_port)

      if $config['stats_allow_ips'] {
        $stats_allow_v4 = sunet::format_nft_set('saddr', filter($config['stats_allow_ips']) | $this | { is_ipaddr($this, 4) })
        $stats_allow_v6 = sunet::format_nft_set('saddr', filter($config['stats_allow_ips']) | $this | { is_ipaddr($this, 6) })
      }
    }

    #
    ensure_resource('file', "/etc/nftables/conf.d/700-frontend-${instance}.nft", {
      ensure  => 'file',
      mode    => '0400',
      content => template('sunet/lb/700-frontend-instance_nftables.nft.erb'),
      validate_cmd => 'nft -c -f %',
      notify  => Service['nftables'],
    })
  }

  if 'letsencrypt_server' in $config and $config['letsencrypt_server'] != $::facts['os']['fqdn'] {
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
    if $v =~ Hash {
      each($v) | $name, $params | {
        sunet::lb::api::instance { "api_${instance}_${k}_${name}":
          site_name   => $site_name,
          backend_ips => $params['ips'],
          api_port    => $api_port,
        }
      }
    }
  }
}
