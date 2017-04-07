class sunet::pypi (
    $user   = 'pypi',
    $home   = '/opt/pypi',
    $chroot = '/opt/pypi/chroot'
) {
    package { ['rush']:
      ensure     => absent,
    } ->
    user {'pypi_user':
      name       => $user,
      shell      => '/bin/false',
      managehome => true,
      home       => '/opt/pypi',
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
    }
    file { "${chroot}":
      ensure  => directory,
      owner   => $user,
      group   => $user,
      recurse => true,
    } ->
    file { "${chroot}/packages":
      ensure  => directory,
      owner   => $user,
      group   => $user,
      recurse => true,
    } ->
    sunet::system_user {'www-data': username => 'www-data', group => 'www-data' } ->
    file { '/opt/pypi/nginx':
      ensure  => directory,
      owner   => 'www-data',
      group   => 'www-data',
      recurse => true,
    } ->
    file { '/opt/pypi/nginx/etc':
      ensure  => directory,
      owner   => 'www-data',
      group   => 'www-data',
      recurse => true,
    } ->
    file { '/opt/pypi/nginx/etc/default.conf':
        ensure  => file,
        owner   => 'www-data',
        group   => 'www-data',
        mode    => '0440',
        content => template('sunet/pypi/nginx_conf.erb'),
    } ->
    file { '/opt/pypi/pypiserver/etc/start.sh':
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
        compose_dir  => '/opt/pypi/compose',
        content => $content,
    }
}
