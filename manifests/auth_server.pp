define sunet::auth_server(
    String $service_name,
    String $server_name     = $::fqdn,
    String $port            = '443',
    String $config,
    String $username        = 'sunet',
    String $group           = 'sunet',
    String $haproxy_cert    = 'snakeoil',
    String $base_dir        = '/opt/sunet',
) {

    ensure_resource('sunet::system_user', $username, {
        username => $username,
        group    => $group,
    })

    if has_key($::tls_certificates, $::fqdn) and has_key($::tls_certificates[$::fqdn], $haproxy_cert) {
        $cert = $::tls_certificates[$::fqdn][$haproxy_cert]
        $key = $::tls_certificates[$::fqdn]["${haproxy_cert}_key"]
        sunet::haproxy::simple_setup { "${service_name}-haproxy":
            server_name => $server_name,
            cert        => $cert,
            key         => $key,
            content     => template('sunet/auth_server/haproxy.cfg.erb'),
            allow_clients => [$facts['cosmos']['frontend_server_addrs'],
            $facts['cosmos']['monitor_server_addrs'],
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
        sunet::misc::create_cfgfile { "${base_dir}/${service_name}/etc/keystore.jwks":
            content => safe_hiera("${service_name}_jwks")
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
            subscribe    => [Sunet::Haproxy::Simple_setup["$service_name-haproxy"]],
        }
        } else {
            warning("No snakeoil certificate found for host ${::fqdn} - not configuring simple haproxy")
        }
}
