# This is the main class of the sunet::gitlab module.
class sunet::gitlab {

    # Application specific password for Crowd.
    # The variable is used in the gitlab.rb template.
    $crowd_password = safe_hiera('crowd_password')

    # root password for the Gitlab app.
    # The variable is used in the gitlab.rb template.
    $gitlab_root_password = safe_hiera('gitlab_root_password')

    # Password for user gitlab in the PostgreSQL database.
    # The variable is used in the gitlab.rb template.
    $postgres_gitlab_password = safe_hiera('postgres_gitlab_password')

    # The following are used by the Gitlab container
    user { 'git': ensure => present,
        system           => true,
        home             => '/var/opt/gitlab',
        shell            => '/bin/sh',
    }
    -> user { 'gitlab-www': ensure => present,
        system                     => true,
        home                       => '/var/opt/gitlab/nginx',
        shell                      => '/bin/false',
    }
    -> user { 'gitlab-redis': ensure => present,
        system                       => true,
        home                         => '/var/opt/gitlab/redis',
        shell                        => '/bin/false',
    }
    -> user { 'gitlab-psql': ensure => present,
        system                      => true,
        home                        => '/var/opt/gitlab/postgresql',
        shell                       => '/bin/sh',
    }

    # The following is used by the Nginx container
    -> user { 'www-data': ensure => present,
        system                   => true,
        home                     => '/var/opt/nginx',
        shell                    => '/usr/sbin/nologin',
    }

    # The following is used by the Redis container
    -> user { 'redis': ensure => present,
        system                => true,
        home                  => '/var/opt/redis',
        shell                 => '/bin/false',
    }

    # The following is used by the PostgreSQL container
    -> user { 'postgres': ensure => present,
        system                   => true,
        home                     => '/var/opt/postgresql',
        shell                    => '/bin/sh',
    }

    # Directories that will be volume mounted in containers
    -> file { '/etc/gitlab':
        ensure => directory,
        path   => '/etc/gitlab',
        mode   => '0755',
    }
    -> file { '/var/opt/gitlab':
        ensure => directory,
        owner  => 'git',
        group  => 'root',
        path   => '/var/opt/gitlab',
        mode   => '0755',
    }
    -> file { '/var/log/gitlab':
        ensure => directory,
        owner  => 'git',
        group  => 'root',
        path   => '/var/log/gitlab',
        mode   => '0755',
    }
    -> file { '/var/opt/redis':
        ensure => directory,
        owner  => 'redis',
        group  => 'root',
        path   => '/var/opt/redis',
        mode   => '0755',
    }
    -> file { '/var/log/redis':
        ensure => directory,
        owner  => 'redis',
        group  => 'root',
        path   => '/var/log/redis',
        mode   => '0755',
    }
    -> file { '/var/opt/postgresql':
        ensure => directory,
        owner  => 'postgres',
        group  => 'root',
        path   => '/var/opt/postgresql',
        mode   => '0755',
    }

    # The private key for the certificate used by Nginx
    # The public part is distributed using Cosmos.
    -> sunet::snippets::secret_file { '/etc/gitlab/ssl/gitlab.nordu.net.key':
        hiera_key => 'gitlab_nordu_net_key'
    }

    # The SSH host-keys used by Gitlab for SSH-based git access.
    # The public part is distributed using Cosmos. 
    -> sunet::snippets::secret_file { '/etc/gitlab/ssh_host_rsa_key':
        hiera_key => 'ssh_host_rsa_key'
    }
    -> sunet::snippets::secret_file { '/etc/gitlab/ssh_host_ed25519_key':
        hiera_key => 'ssh_host_ed25519_key'
    }
    -> sunet::snippets::secret_file { '/etc/gitlab/ssh_host_ecdsa_key':
        hiera_key => 'ssh_host_ecdsa_key'
    }

    # This file will contain clear text passwords after puppet
    # has extracted the necessary pieces from the GPG encrypted
    # hiera file and should therefore only be readable by the
    # git user that Gitlab uses and root.
    -> file { '/etc/gitlab/gitlab.rb':
        ensure  => file,
        owner   => 'git',
        group   => 'root',
        path    => '/etc/gitlab/gitlab.rb',
        mode    => '0440',
        content => template('sunet/gitlab/gitlab_rb.erb'),
    }

    -> file { '/etc/gitlab/nginx':
        ensure => directory,
        path   => '/etc/gitlab/nginx',
        mode   => '0755',
    }

    -> file { '/etc/gitlab/nginx/gitlab-ssl':
        ensure  => file,
        path    => '/etc/gitlab/nginx/gitlab-ssl',
        mode    => '0440',
        content => template('sunet/gitlab/gitlab-ssl.erb'),
    }

    # Set up backup to run once a day at 02:00.
    # The backup is placed in /var/opt/gitlab/backup
    # and is saved for a week as can been seen
    # by the setting in the gitlab_rb.erb template.
    # To restore a backup execute the commands found
    # in the doc inside the container:
    # http://doc.gitlab.com/ce/raketasks/backup_restore.html#omnibus-installations
    -> cron { 'gitlab_backup':
        command => '/usr/bin/docker exec gitlab /opt/gitlab/bin/gitlab-rake gitlab:backup:create CRON=1',
        user    => 'root',
        hour    => 2,
        minute  => 0,
    }

    sunet::docker_run { 'gitlab-postgres':
        image    => 'postgres',
        imagetag => '9.2',
        volumes  => ['/var/opt/postgresql:/var/opt/postgresql'],
        env      => ['POSTGRES_DB=gitlabhq_production',
                    'POSTGRES_USER=gitlab',
                    "POSTGRES_PASSWORD=${postgres_gitlab_password}",
                    'PGDATA=/var/opt/postgresql']
    }

    sunet::docker_run { 'gitlab-redis':
        image    => 'docker.sunet.se/eduid/redis',
        imagetag => 'latest',
        volumes  => ['/var/log/redis:/var/log/redis',
                    '/var/opt/redis:/data',
                    '/etc/gitlab/redis/redis.conf:/etc/redis/redis.conf'],
    }

    sunet::docker_run { 'gitlab':
        image    => 'gitlab/gitlab-ce',
        imagetag => '8.16.1-ce.0',
        ports    => ['22:22'],
        volumes  => ['/etc/gitlab:/etc/gitlab',
                    '/var/log/gitlab:/var/log/gitlab',
                    '/var/opt/gitlab:/var/opt/gitlab'],
        depends  => ['gitlab-postgres', 'gitlab-redis']
    }

    # Gitlab takes some time to start and because of that the
    # upstream host gitlab:8181 might not be ready the first time
    # that Nginx tries to reach it. Therefore we allow the Nginx
    # container to restart, and retry the upstream, up to 10 times
    # before failing and shutting down.
    sunet::docker_run { 'gitlab-nginx':
        image            => 'docker.sunet.se/eduid/nginx',
        imagetag         => 'latest',
        ports            => ['80:80', '443:443'],
        volumes          => ['/var/log/nginx:/var/log/nginx',
                            '/etc/gitlab/nginx/gitlab-ssl:/etc/nginx/sites-enabled/default:ro',
                            '/etc/gitlab/ssl:/etc/nginx/ssl:ro'],
        extra_parameters => ['--restart=on-failure:10'],
        depends          => ['gitlab']
    }

}
