class sunet::gitlab {

    $crowd_password = hiera('crowd_password', 'NOT_SET_IN_HIERA')

    user { 'git': ensure => present,
        system => true,
        home   => '/var/opt/gitlab',
        shell  => '/bin/sh',
    } ->
    user { 'gitlab-www': ensure => present,
        system => true,
        home   => '/var/opt/gitlab/nginx',
        shell  => '/bin/false',
    } ->
    user { 'gitlab-redis': ensure => present,
        system => true,
        home   => '/var/opt/gitlab/redis',
        shell  => '/bin/false',
    } ->
    user { 'gitlab-psql': ensure => present,
        system => true,
        home   => '/var/opt/gitlab/postgresql',
        shell  => '/bin/sh',
    } ->
    sunet::snippets::secret_file { '/etc/gitlab/ssl/gitlab.nordu.net.key':
        hiera_key => 'gitlab_nordu_net_key'
    } ->
    file { '/etc/gitlab/gitlab.rb':
        ensure  => file,
        path    => '/etc/gitlab/gitlab.rb',
        mode    => '0640',
        content => template('sunet/gitlab/gitlab_rb.erb'),
    } ->
    sunet::docker_run {'gitlab':
        image    => 'gitlab/gitlab-ce',
        imagetag => 'latest',
        volumes  => ['/etc/gitlab:/etc/gitlab','/var/log/gitlab:/var/log/gitlab','/var/opt/gitlab:/var/opt/gitlab'],
        ports    => ['22:22','80:80','443:443'],
    }

}
