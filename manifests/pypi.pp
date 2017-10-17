class sunet::pypi (
    $user   = 'pypi',
    $home   = '/opt/pypi',
) {
    user {'pypi_user':
      name       => $user,
      shell      => '/bin/false',
      managehome => true,
      home       => '/opt/pypi',
    } ->

    # OpenSSH require that the home dir is owned by root in
    # order to allow chrooting the connecting user to it.
    file { "${home}":
      ensure  => directory,
      owner   => 'root',
      group   => 'root',
      recurse => false,
    } ->

    file { "${home}/.ssh":
      ensure  => directory,
      owner   => $user,
      group   => $user,
      recurse => true,
    } ->
    file { "${home}/pypiserver":
      ensure  => directory,
      owner   => $user,
      group   => $user,
      recurse => true,
    } ->
    file { "${home}/pypiserver/etc":
      ensure  => directory,
      owner   => $user,
      group   => $user,
      recurse => true,
    } ->
    ssh_authorized_key { "pypi_package_key":
      ensure  => present,
      user    => $user,
      type    => "ssh-rsa",
      key     => "AAAAB3NzaC1yc2EAAAADAQABAAACAQC2bEPvMFlJwrdchpSyrKgG3Gv0ZHM0DKxHxMctfBNMFkXYzUiRc1kIsuHwca+w4iHPrSsLSbeLWL5rlOyON1xtWvXr2aqCIOr3N64zuaKvlNx9Sty6UFXuHUOo98F+1Zk3tFFXN/hCod+BGp2SqAR2ajWTVn7E+9MrmrSRXkFKUDonlX7LfVosSxUiqJ6Ths00syq01X28dxtrj6yk6Py9bgr8Vl/8ZUzNzc7Tr1y1I/96EvlSftzc5LIzuhUSt9Ge7PKudMi8qhlgyflHleEAy01AE65w+GGxt7kDyjmvv+PnQMbW4gK6R8hylGQMMdTZx/eAoZJSJTHjWlITY2Wm7oGphTVNY1hE1PNpYhSRLBFcpOcR5iViVC18ygFAncKAIDl6P4HNj03JOHV2wkKtbkscPG11G6w+hrwc8gjCuGXWwPYvtgj6t5RO0LiZnYqgVyrbjwJ2CDP2l9xAiPVbtHFby5CvmZmXWUW8XCJWOwJjKjaXy8IWt+g4TmIKeTnU+zU7Iu1EfI0lqlIzrVpnuf0MiE/2MPKYIp2YDbvy2KFq7ebS6Kd5TIupevmbsPQsZMBz7RNQV1btSGoi5bgowa03z5SLtho15UEloBS77b0SeXs/bx8+ghjx5o+DEuqWaTAcj1uPo1clWuVRhGoE+PYhzy+Ony2PLdcfm9GbpQ==",
      target  => "${home}/.ssh/authorized_keys",
    } ->
    # These changes adds chrooting for the pypi user as well as disables
    # some stuff that it doesnt need, such as forwarding and tunnel.
    file { "/etc/ssh/sshd_config":
        ensure  => file,
        owner   => 'root',
        group   => 'root',
        mode    => '0644',
        content => template('sunet/pypi/sshd_config.erb'),
        notify  => Service['ssh'],
    } ->
    class { 'sunet::security::configure_sshd':
      configure_sftp => false,
    }
    sunet::misc::ufw_allow { "allow-ssh-from-all":
      from => 'any',
      port => '22',
    }

    file { "${home}/packages":
      ensure  => directory,
      owner   => $user,
      group   => $user,
      recurse => true,
    } ->
    sunet::system_user {'www-data': username => 'www-data', group => 'www-data' } ->
    file { "${home}/nginx":
      ensure  => directory,
      owner   => 'www-data',
      group   => 'www-data',
      recurse => true,
    } ->
    file { "${home}/nginx/etc":
      ensure  => directory,
      owner   => 'www-data',
      group   => 'www-data',
      recurse => true,
    } ->
    file { "${home}/nginx/etc/default.conf":
        ensure  => file,
        owner   => 'www-data',
        group   => 'www-data',
        mode    => '0440',
        content => template('sunet/pypi/nginx_conf.erb'),
    } ->
    file { "${home}/pypiserver/etc/start.sh":
        ensure  => file,
        owner   => $user,
        group   => $user,
        mode    => '0775',
        content => template('sunet/pypi/start_pypiserver.sh.erb'),
    } ->
    exec { 'create_dhparam_pem':
        command => '/usr/bin/openssl dhparam -out /opt/pypi/nginx/dhparam.pem 2048',
        unless  => '/usr/bin/test -s /opt/pypi/nginx/dhparam.pem',
    }

    $content = template('sunet/pypi/docker-compose_pypi.yml.erb')
    sunet::docker_compose {'pypi_docker_compose':
        service_name => 'pypi',
        description  => 'pypi service',
        compose_dir  => "${home}/compose",
        content => $content,
    }
}
