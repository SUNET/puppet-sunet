# auth_server
define sunet::auth_server(
    String $service_name,
    Hash $config,
    String $cert_file,
    String $key_file,
    String $server_name      = $facts['networking']['fqdn'],
    String $port             = '443',
    String $username         = 'sunet',
    String $group            = 'sunet',
    String $base_dir         = '/opt/sunet',
    Boolean $saml_sp         = false,
    String $pysaml2_base_url = "https://${facts['networking']['fqdn']}/saml2/sp",
    Array $allow_clients     = [$facts['cosmos']['frontend_server_addrs']],
    Array $lb_hosts          = $facts['cosmos']['frontend_server_hosts'],
    String $pyff_version     = '2.0.0',
    String $ca_file_path     = '/etc/ssl/certs/infra.crt',

) {

    ensure_resource('sunet::system_user', $username, {
        username => $username,
        group    => $group,
    })

    sunet::haproxy::simple_setup { "${service_name}-haproxy":
        server_name   => $server_name,
        cert          => $cert_file,
        key           => $key_file,
        content       => template('sunet/auth_server/haproxy.cfg.erb'),
        allow_clients => flatten($allow_clients),
        port          => $port,
    }

    sunet::misc::create_root_dir { "${base_dir}/${service_name}/etc":
        group => $group,
        mode  => '0750',
    }

    sunet::misc::create_cfgfile { "${base_dir}/${service_name}/etc/config.yaml":
        content => inline_template("<%= @config['app_config'].to_yaml %>"),
        group   => $group,
        force   => true,
        notify  => [Sunet::Docker_compose["${service_name}-docker-compose"]],
    }

    $keystore = safe_hiera("${service_name}_jwks")
    sunet::misc::create_cfgfile { "${base_dir}/${service_name}/etc/keystore.jwks":
        content => inline_template('<%= @keystore.to_json %>'),
        group   => $group,
        force   => true,
        notify  => [Sunet::Docker_compose["${service_name}-docker-compose"]],
    }

    if $::facts['dockerhost2'] == 'yes' {
      $auth_server_allow_v4 = filter(flatten($allow_clients)) |$this| { is_ipaddr($this, 4) or $this == 'any' }
      $auth_server_saddr    = sunet::format_nft_set('ip saddr', $auth_server_allow_v4)

      # docker compose derives the project name from the directory holding the
      # compose file, i.e. $service_name (normalised to lowercase alnum/-/_).
      $compose_project = downcase(regsubst($service_name, '[^a-zA-Z0-9_-]', '', 'G'))
      $haproxy_ip      = $facts.dig('sunet_docker_compose_ips', $compose_project, 'haproxy', 'ipv4')

      if $haproxy_ip != undef and is_ipaddr($haproxy_ip, 4) {
        sunet::nftables::rule { "${name}-dnat-${port}-to-haproxy":
          rule => 'add rule ip nat prerouting iifname != "br-*" ' +
                  "${auth_server_saddr} " +
                  "ip daddr ${facts['networking']['ip']} " +
                  "tcp dport ${port} counter dnat to ${haproxy_ip}:443 " +
                  "comment \"${service_name}: DNAT HTTPS directly to container\""
        }

        sunet::nftables::rule { "${name}-allow-post-dnat-${port}-to-haproxy":
          rule => 'add rule inet filter forward iifname != "br-*" oifname "br-*" ' +
                  "${auth_server_saddr} " +
                  "ip daddr ${haproxy_ip} tcp dport 443 counter accept " +
                  "comment \"${service_name}: allow post-DNAT HTTPS to container\""
        }
      } else {
        notice('sunet::auth_server: IP of the ' +
          "${compose_project}/haproxy container is not known yet - " +
          'not setting up the DNAT rules (will probably work next time)')
      }

      include sunet::nftables::container_dnat

      $dnat_out_file = "/etc/nftables/conf.d/650-container_dnat-${compose_project}-haproxy.nft"
      $dnat_exec_start_post = 'ExecStartPost=-/usr/local/sbin/sunet_nft_container_dnat ' +
        "--project '${compose_project}' " +
        '--service haproxy ' +
        "--host-ip '${facts['networking']['ip']}' " +
        "--port '${port}' " +
        "--saddr-set '${auth_server_saddr}' " +
        "--comment-prefix '${service_name}' " +
        "--out '${dnat_out_file}' " +
        '--wait 60'
    }

    $auth_server_service_extras = $::facts['dockerhost2'] ? {
      'yes'   => [$dnat_exec_start_post],
      default => [],
    }

    if $saml_sp {
        sunet::misc::create_cfgfile { "${base_dir}/${service_name}/etc/saml2_settings.py":
            content => template('sunet/auth_server/saml2_settings.py.erb'),
            group   => $group,
            force   => true,
            notify  => [Sunet::Docker_compose["${service_name}-docker-compose"]],
        }
        sunet::misc::create_key_file { "${base_dir}/${service_name}/etc/saml.key":
            hiera_key => "${service_name}_saml_key",
            group     => $group,
            notify    => [Sunet::Docker_compose["${service_name}-docker-compose"]],
        }
    }

    $mongodb_root_username = safe_hiera("${service_name}_mongodb_root_username")
    $mongodb_root_password = safe_hiera("${service_name}_mongodb_root_password")
    $haproxy_tag = $config["haproxy_tag"]
    $auth_server_tag = $config["auth_server_tag"]
    $content = template('sunet/auth_server/docker-compose_auth_server.yml.erb')
    sunet::docker_compose { "${service_name}-docker-compose":
        service_name   => $service_name,
        content        => $content,
        description    => 'sunet auth server application',
        compose_dir    => '/opt/sunet/compose',
        service_extras => $auth_server_service_extras,
        subscribe      => [
            Sunet::Haproxy::Simple_setup["${service_name}-haproxy"],
            Sunet::Misc::Create_cfgfile["${base_dir}/${service_name}/etc/config.yaml"],
            Sunet::Misc::Create_cfgfile["${base_dir}/${service_name}/etc/keystore.jwks"],
        ],
    }
}
