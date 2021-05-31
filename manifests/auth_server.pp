define sunet::auth_server(
    String $service_name,
    String $config,
    String $cert_file,
    String $key_file,
    String $server_name     = $::fqdn,
    String $port            = '443',
    String $username        = 'sunet',
    String $group           = 'sunet',
    String $base_dir        = '/opt/sunet',
) {

    ensure_resource('sunet::system_user', $username, {
        username => $username,
        group    => $group,
    })

    # Pre setup for haproxy
    ensure_resource(sunet::misc::system_user, 'haproxy', {group => 'haproxy' })
    sunet::misc::certbundle {"${::fqdn}_haproxy":
        group     => 'haproxy',
        bundle    => ["cert=${cert_file}",
          "key=${key_file}",
          "out=private/${::fqdn}_haproxy.crt",
        ],
    }

    sunet::haproxy::simple_setup { "${service_name}-haproxy":
        server_name   => $server_name,
        cert          => $cert_file,
        key           => $key_file,
        content       => template('sunet/auth_server/haproxy.cfg.erb'),
        allow_clients => [
            $facts['cosmos']['frontend_server_addrs'],
            ],
        port          => $port,
    }

    sunet::misc::create_dir { "${base_dir}/${service_name}/etc":
        owner => $user,
        group => $group,
        mode => '0700',
    }
    sunet::misc::create_cfgfile { "${base_dir}/${service_name}/etc/config.yaml":
        content => $config,
        group   => $group,
        force   => true,
        notify  => [Sunet::Docker_compose["$service_name-docker-compose"]],
    }
    $keystore = safe_hiera("${service_name}_jwks")
    sunet::misc::create_cfgfile { "${base_dir}/${service_name}/etc/keystore.jwks":
        content => inline_template("<%= @keystore.to_json %>"),
        group   => $group,
        force   => true,
        notify  => [Sunet::Docker_compose["$service_name-docker-compose"]],
    }

    $content = template('sunet/auth_server/docker-compose_auth_server.yml.erb')
    sunet::docker_compose {"$service_name-docker-compose":
        service_name => $service_name,
        content      => $content,
        description  => "sunet auth server application",
        compose_dir  => '/opt/sunet/compose',
        subscribe    => [
            Sunet::Haproxy::Simple_setup["$service_name-haproxy"],
            Sunet::Misc::Create_cfgfile["${base_dir}/${service_name}/etc/config.yaml"],
            Sunet::Misc::Create_cfgfile["${base_dir}/${service_name}/etc/keystore.jwks"],
        ],
    }
}
