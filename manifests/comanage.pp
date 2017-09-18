class sunet::comanage (
    $user   = 'root',
    $home   = '/root/comanage',
) {

    sunet::system_user {'postgres': username => 'postgres', group => 'postgres' }

    $content = template('sunet/comanage/docker-compose_comanage.yml.erb')
    sunet::docker_compose {'comanage_docker_compose':
        service_name => 'comanage',
        description  => 'comanage service',
        compose_dir  => "${home}",
        content => $content,
    }

}
