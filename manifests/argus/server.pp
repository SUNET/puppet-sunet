# @summary class to Argus Server
# @param docker_image    Specific Argus image
# @param docker_tag      Specific Argus image tag
# @param url             Specific hostname where Argus will be running
# @param argus_clients   Hiera Variable that contains list of prefixes allowed to reach Argus
class sunet::argus::server (
  String  $docker_image     = "docker.sunet.se/sunet/argus-api",
  String  $docker_tag       = "v2.5.0_sunetbuild",
  String  $url              = $facts['networking']['hostname'],
  String  $argus_clients    = ''
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
        content => template('sunet/argus/localsettings.py.erb'),
        require => File[$argus_config_dir]
    }

    file { '/opt/nginx_etc/conf.d/default.conf':
        ensure  => file,
        group   => 'root',
        mode    => '0755',
        content => template('sunet/argus/default.conf.erb'),
        require => File[$nginx_config_dir]
    }

    sunet::docker_compose {'argus_docker_compose':
        service_name     => 'argus',
        description      => 'Argus Alarm Aggregator for SUNET CNaaS',
        compose_filename => 'docker-compose.yml',
        compose_dir      => '/opt',
        content          => template('sunet/argus/docker-compose.yml.erb'),
    }

    if $argus_clients != '' {
        $argus_allow_networks = lookup($argus_clients, undef, undef, [])
        $argus_interface = safe_hiera('argus_interface',$facts['interface_default'])
        sunet::nftables::docker_expose { 'allow_https' :
            allow_clients   => $argus_allow_networks,
            port            => '443',
            iif             => $argus_interface,
        }
    } else  {
        warning('No configured Client IPs for argus. Not allowing HTTPS access for anyone.')
    }

}
