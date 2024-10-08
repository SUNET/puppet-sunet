define sunet::auth_server(
    String $service_name,
    Hash $config,
    String $cert_file,
    String $key_file,
    String $server_name      = $::fqdn,
    String $port             = '443',
    String $username         = 'sunet',
    String $group            = 'sunet',
    String $base_dir         = '/opt/sunet',
    Boolean $saml_sp         = false,
    String $pysaml2_base_url = "https://$::fqdn/saml2/sp",
    Array $allow_clients     = [$facts['cosmos']['frontend_server_addrs']],
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
        notify  => [Sunet::Docker_compose[$service_name-docker-compose]],
    }

    $keystore = safe_hiera("${service_name}_jwks")
    sunet::misc::create_cfgfile { "${base_dir}/${service_name}/etc/keystore.jwks":
        content => inline_template('<%= @keystore.to_json %>'),
        group   => $group,
        force   => true,
        notify  => [Sunet::Docker_compose[$service_name-docker-compose]],
    }

    if $saml_sp {
        sunet::misc::create_cfgfile { "${base_dir}/${service_name}/etc/saml2_settings.py":
            content => template('sunet/auth_server/saml2_settings.py.erb'),
            group   => $group,
            force   => true,
            notify  => [Sunet::Docker_compose[$service_name-docker-compose]],
        }
        sunet::misc::create_key_file { "${base_dir}/${service_name}/etc/saml.key":
            hiera_key => "${service_name}_saml_key",
            group     => $group,
            notify    => [Sunet::Docker_compose[$service_name-docker-compose]],
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
            Sunet::Haproxy::Simple_setup[$service_name-haproxy],
            Sunet::Misc::Create_cfgfile["${base_dir}/${service_name}/etc/config.yaml"],
            Sunet::Misc::Create_cfgfile["${base_dir}/${service_name}/etc/keystore.jwks"],
        ],
    }
}
