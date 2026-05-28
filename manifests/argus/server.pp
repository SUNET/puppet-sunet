# @summary class to Argus Server
# @param docker_image     Specific Argus image
# @param docker_tag       Specific Argus image tag
# @param url              Specific url where Argus will be running
# @param argus_clients    Hiera Variable that contains list of prefixes allowed to reach Argus
# @param argus_debug      Boolean variable to enable DJANGO debug on the server.
# @param argus_auth_type  Boolean variable to enable one type of SSO inlogging local or keycloak.
#
# Hiera variables to define on the target host:
# argus_email_host
# argus_email_user
# argus_email_from
# argus_sms_gateway
# django_secret_key
# argus_db_password
# argus_clients - (ex: argus_front_clients:  [ 10.1.11.0/24, 10.1.0.0/24 ] )
#
# If auth type keycloak is selected then:
# argus_sso_keycloak hashmap with
#   auth_keycloak_public_key (from https://norpan-keycloak1.cnaas.sunet.se/realms/norpan)
#   auth_keycloak_key (client-id)
#   auth_keycloak_secret (client secret)
#   auth_keycloak_base_url (https://<url>/realms/<realm>)
#   kc_idp_hint (idp hint towards swamid SAML flow if present)
#
#####
class sunet::argus::server (
  String  $docker_image     = 'docker.sunet.se/sunet/argus-api',
  String  $docker_tag       = 'v2.5.0_sunetbuild',
  String  $url              = $facts['networking']['hostname'],
  String  $argus_auth_type  = 'local',
  Boolean $argus_debug      = false,
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
          allow_clients => $argus_allow_networks,
          port          => '443',
          iif           => $argus_interface,
        }
    } else  {
        warning('No configured Client IPs for argus. Not allowing HTTPS access for anyone.')
    }

}
