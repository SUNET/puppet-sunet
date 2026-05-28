# docker registry
class sunet::docker_registry (
    String $registry_public_hostname = 'docker.example.com',
    String $fqdn                     = 'docker-prod-1.example.com',
    String $registry_images_basedir  = '/var/lib/registry',
    String $registry_conf_basedir    = '/etc/docker/registry',
    String $apache_conf_basedir      = '/etc/apache2',
    String $registry_cleanup_basedir = '/usr/local/bin/clean-registry',
    String $registry_tag             = '2',
) {
    service { 'sunet-docker-registry':
      ensure   => 'stopped',
      enable   => false,
      provider => 'systemd',  # puppet is really bad at figuring this out
    }

    file { '/etc/systemd/system/sunet-docker-registry.service':
        ensure  => absent,
    }

    # remove now unused config file
    file { "${registry_conf_basedir}/config.yml":
        ensure  => absent,
    }

    file { "${apache_conf_basedir}/sites-available/registry-auth-ssl.conf":
        ensure  => absent,
    }

    file { "/etc/ssl/certs/${registry_public_hostname}-client-ca.crt":
        ensure  => absent,
    }

    file { "${registry_conf_basedir}/docker-registry/docker-compose_docker_registry.yml":
        ensure  => absent,
    }

    file { "${registry_conf_basedir}/docker-registry":
        ensure => absent,
        force  => true,
    }

    file { $registry_conf_basedir:
        ensure => absent,
        force  => true,
    }

    docker_network { 'registry_net':
      ensure => present,
    }

    # These are run as 3 different containers, and not in a compose group
    # to simplify their running and ensure they keep running in case of
    # system degradation and/or cleanup scripts going berserk.

    sunet::docker_run { 'registry':
      image                    => 'registry',
      imagetag                 => $registry_tag,
      uid_gid_consistency      => false,
      ports                    => ['127.0.0.1:5000:5000'],
      volumes                  => ['/var/lib/registry:/var/lib/registry:rw'],
      env                      => ['REGISTRY_STORAGE_DELETE_ENABLED=true'],
      net                      => 'registry_net',
      # This is a extra fallback to re-create the net if it gets removed
      # by for example docker system prune -af
      extra_systemd_parameters => {'ExecStartPre' => '-/usr/bin/docker network create registry_net'},
    }

    sunet::docker_run { 'registry-auth':
      # Pull this from the "back-door" via the registry, so we can always get it
      image               => 'localhost:5000/sunet/docker-registry-auth',
      imagetag            => 'stable',
      fetch_docker_image  => false,
      uid_gid_consistency => false,
      ports               => ['443:443'],
      volumes             => [
            "/etc/dehydrated/certs/${fqdn}.key:/etc/ssl/private/${registry_public_hostname}.key:ro",
            "/etc/dehydrated/certs/${fqdn}.crt:/etc/ssl/certs/${registry_public_hostname}.crt:ro",
            "/etc/dehydrated/certs/${fqdn}-chain.crt:/etc/ssl/certs/${registry_public_hostname}-chain.crt:ro",
            "/etc/ssl/certs/infra.crt:/etc/ssl/certs/${registry_public_hostname}-client-ca.crt:ro",
      ],
      env                 => ["SERVER_NAME=${registry_public_hostname}"],
      extra_parameters    => ['--link=registry'],
      depends             => ['registry'],
      net                 => 'registry_net',
    }

    sunet::docker_run { 'always-https':
      image               => 'docker.sunet.se/always-https',
      fetch_docker_image  => false,
      uid_gid_consistency => false,
      ports               => ['80:80'],
      env                 => ['ACME_URL=http://acme-c.sunet.se'],
      net                 => 'bridge',
    }

    sunet::scriptherder::cronjob { 'check_for_updated_docker_image':
        cmd           => '/usr/local/bin/check_for_updated_docker_image',
        hour          => '1',
        minute        => '5',
        ok_criteria   => ['exit_status=0'],
        warn_criteria => ['max_age=5d']
    }

    package {['python-yaml', 'python-ipaddress', 'python-requests']:
        ensure => installed
    }

    file { "${registry_cleanup_basedir}/clean_registry_cron":
        ensure  => file,
        mode    => '0774',
        content => template('sunet/docker_registry/clean_registry_cron.erb')
    }

    sunet::scriptherder::cronjob { 'clean_registry':
        cmd           => "${registry_cleanup_basedir}/clean_registry_cron",
        weekday       => 'Saturday',
        hour          => '9',
        minute        => '3',
        ok_criteria   => ['exit_status=0'],
        warn_criteria => ['max_age=9d']
    }

}
