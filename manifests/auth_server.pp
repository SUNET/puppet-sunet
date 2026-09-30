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

      sunet::nftables::rule { "DNAT port ${port} to haproxy":
        rule => "add rule ip nat prerouting iifname != \"br-*\" ${auth_server_saddr} ip daddr ${facts['networking']['ip']} tcp dport ${port} counter dnat to 172.16.1.2:443 comment \"DNAT HTTPS directly to container\""
      }

      sunet::nftables::rule { "allow post-DNAT traffic to haproxy on ${port}":
        rule => "add rule inet filter forward iifname != \"br-*\" oifname \"br-*\" ${auth_server_saddr} ip daddr 172.16.1.2 tcp dport 443 counter accept comment \"allow post-DNAT HTTPS to container\""
      }
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
        service_name => $service_name,
        content      => $content,
        description  => 'sunet auth server application',
        compose_dir  => '/opt/sunet/compose',
        subscribe    => [
            Sunet::Haproxy::Simple_setup["${service_name}-haproxy"],
            Sunet::Misc::Create_cfgfile["${base_dir}/${service_name}/etc/config.yaml"],
            Sunet::Misc::Create_cfgfile["${base_dir}/${service_name}/etc/keystore.jwks"],
        ],
    }
}
