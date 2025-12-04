# @summary class to Argus Server
# @param docker_image    Specific Argus image
# @param docker_tag      Specific Argus image tag
# @param url             Specific hostname where Argus will be running
class sunet::argus::server (
  String  $docker_image = "docker.sunet.se/sunet/argus-api",
  String  $docker_tag   = "v2.5.0_sunetbuild",
  String  $url          = $facts['networking']['hostname']
){

    $argus_config_dir = '/opt/argus_config'
    $nginx_config_dir = '/opt/nginx_etc/conf.d'

    file { $argus_config_dir:
        ensure => directory,
        mode   => '0755'
    }

    file { $nginx_config_dir:
        ensure => directory,
        mode   => '0755'
    }

    file { '/opt/argus_config/localsettings.py':
        ensure  => file,
        group   => 'root',
        mode    => '0755',
        content => template('argus/localsettings.py.erb'),
        require => File[$argus_config_dir]
    }

    file { '/opt/nginx_etc/conf.d/default.conf':
        ensure  => file,
        group   => 'root',
        mode    => '0755',
        content => template('argus/default.conf.erb'),
        require => File[$nginx_config_dir]
    }

    sunet::docker_compose {'argus_docker_compose':
        service_name     => 'argus',
        description      => 'Argus Alarm Aggregator for SUNET CNaaS',
        compose_filename => 'docker-compose.yml',
        compose_dir      => '/opt',
        content          => template('argus/docker-compose.yml.erb'),
    }

}
