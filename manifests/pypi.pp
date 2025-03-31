# Setup pypi service
class sunet::pypi (
    $user   = 'pypi',
    $home   = '/opt/pypi',
    $servicename = 'pypi.sunet.se',
) {
    user {'pypi_user':
      name       => $user,
      shell      => '/bin/false',
      managehome => true,
      home       => '/opt/pypi',
    }

    ensure_resource('service', 'ssh', {
        ensure => 'running',
        enable => true,
    })
    # OpenSSH require that the home dir is owned by root in
    # order to allow chrooting the connecting user to it.
    file { $home:
      ensure  => directory,
      owner   => 'root',
      group   => $user,
      recurse => false,
    }

    ensure_resource('file', "${home}/.ssh", {
      ensure  => directory,
      mode    => '0700',
      owner   => $user,
      group   => $user,
    })
    file { "${home}/pypiserver":
      ensure  => directory,
      owner   => $user,
      group   => $user,
      recurse => true,
    }
    file { "${home}/pypiserver/etc":
      ensure  => directory,
      owner   => $user,
      group   => $user,
      recurse => true,
    }
    ssh_authorized_key { 'pypi_package_key':
      ensure => present,
      user   => $user,
      type   => 'ssh-rsa',
      key    => 'AAAAB3NzaC1yc2EAAAADAQABAAACAQC2bEPvMFlJwrdchpSyrKgG3Gv0ZHM0DKxHxMctfBNMFkXYzUiRc1kIsuHwca+w4iHPrSsLSbeLWL5rlOyON1xtWvXr2aqCIOr3N64zuaKvlNx9Sty6UFXuHUOo98F+1Zk3tFFXN/hCod+BGp2SqAR2ajWTVn7E+9MrmrSRXkFKUDonlX7LfVosSxUiqJ6Ths00syq01X28dxtrj6yk6Py9bgr8Vl/8ZUzNzc7Tr1y1I/96EvlSftzc5LIzuhUSt9Ge7PKudMi8qhlgyflHleEAy01AE65w+GGxt7kDyjmvv+PnQMbW4gK6R8hylGQMMdTZx/eAoZJSJTHjWlITY2Wm7oGphTVNY1hE1PNpYhSRLBFcpOcR5iViVC18ygFAncKAIDl6P4HNj03JOHV2wkKtbkscPG11G6w+hrwc8gjCuGXWwPYvtgj6t5RO0LiZnYqgVyrbjwJ2CDP2l9xAiPVbtHFby5CvmZmXWUW8XCJWOwJjKjaXy8IWt+g4TmIKeTnU+zU7Iu1EfI0lqlIzrVpnuf0MiE/2MPKYIp2YDbvy2KFq7ebS6Kd5TIupevmbsPQsZMBz7RNQV1btSGoi5bgowa03z5SLtho15UEloBS77b0SeXs/bx8+ghjx5o+DEuqWaTAcj1uPo1clWuVRhGoE+PYhzy+Ony2PLdcfm9GbpQ==', # lint:ignore:140chars
      target => "${home}/.ssh/authorized_keys",
    }
    ssh_authorized_key { 'pypi_package_key_ci_sunet_se':
      ensure => present,
      user   => $user,
      type   => 'ssh-rsa',
      key    => 'AAAAB3NzaC1yc2EAAAADAQABAAABAQC9Hx8wpyNeCcMoT+wwT79Ucfi0iqvVr711zD4ueqVk/yEjjuL28Ca7krcUreJm1MI45uPU+I26PW4as+zl+V4tiC4P5tV0etmu5PkowmLuHi+vn6KBbsW7vXWn6L87DqaHY02rYXnOulI/G8BEK56+ERfKFLdQoDrQNFBn6gMhn+EII3V/tfodXT5/sTrFp67uwdYwUUa0WHwbPuEPj1jZU5G83kCs2/Pa1YLdZ5Vya0FjijNxy9LEDbdu7lrWwGH9tW+9sdycEsZZmFF7IWZad/fLcQrf8uJJu58SH/h3R7rZfaaZet76sMoiayviTQac/bSB5Mj07O/rRMi12KRJ', # lint:ignore:140chars
      target => "${home}/.ssh/authorized_keys",
    }
    # These changes adds chrooting for the pypi user as well as disables
    # some stuff that it doesnt need, such as forwarding and tunnel.
    file { '/etc/ssh/sshd_config':
        ensure  => file,
        owner   => 'root',
        group   => 'root',
        mode    => '0644',
        content => template('sunet/pypi/sshd_config.erb'),
        notify  => Service['ssh'],
    }

    sunet::misc::ufw_allow { 'allow-ssh-from-all':
      from => 'any',
      port => '22',
    }

    file { "${home}/packages":
      ensure  => directory,
      owner   => $user,
      group   => $user,
      recurse => true,
    }
    sunet::system_user {'www-data': username => 'www-data', group => 'www-data' }
    file { "${home}/nginx":
      ensure  => directory,
      owner   => 'www-data',
      group   => 'www-data',
      recurse => true,
    }
    file { "${home}/nginx/etc":
      ensure  => directory,
      owner   => 'www-data',
      group   => 'www-data',
      recurse => true,
    }
    file { "${home}/nginx/etc/default.conf":
        ensure  => file,
        owner   => 'www-data',
        group   => 'www-data',
        mode    => '0440',
        content => template('sunet/pypi/nginx_conf.erb'),
    }
    file { "${home}/pypiserver/etc/start.sh":
        ensure  => file,
        owner   => $user,
        group   => $user,
        mode    => '0775',
        content => template('sunet/pypi/start_pypiserver.sh.erb'),
    }
    exec { 'create_dhparam_pem':
        command => '/usr/bin/openssl dhparam -out /opt/pypi/nginx/dhparam.pem 2048',
        unless  => '/usr/bin/test -s /opt/pypi/nginx/dhparam.pem',
    }

    # nftables
    sunet::nftables::allow { 'allow-http':
      from => any,
      port => 80,
    }
    sunet::nftables::allow { 'allow-https':
      from => any,
      port => 443,
    }

    # Use plain cron as to not bog down other scriptherder checks with many many logs
    cron { 'set_packages_immutable':
        ensure  => present,
        command => "/usr/bin/chattr +i ${home}/packages/*",
        user    => 'root',
        minute  => '*/1',
    }

    $content = template('sunet/pypi/docker-compose_pypi.yml.erb')
    sunet::docker_compose {'pypi_docker_compose':
        service_name => 'pypi',
        description  => 'pypi service',
        compose_dir  => "${home}/compose",
        content      => $content,
    }
}
