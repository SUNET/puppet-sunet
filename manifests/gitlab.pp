class sunet::gitlab {

    # Application specific password for Crowd.
    # The variable is used in the gitlab.rb template.
    $crowd_password = hiera('crowd_password', 'NOT_SET_IN_HIERA')


    # Unbound is installed since a resolver is needed
    # for the VM and sunet::unbound was not stable
    # at the time of testing. It was also discovered 
    # that a unbound user was needed to use docker-unbound.
    package { 'unbound':
        ensure => installed
    } ->

    # The following users are used by Gitlab
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

    # Set up backup to run once a day at 02:00.
    # The backup is placed in /var/opt/gitlab/backup
    # and is saved for a week as can been seen
    # by the setting in the gitlab_rb.erb template.
    # To restore a backup execute the commands found 
    # in the doc inside the container:
    # http://doc.gitlab.com/ce/raketasks/backup_restore.html#omnibus-installations
    cron { 'gitlab_backup':
        command => '/usr/bin/docker exec gitlab /opt/gitlab/bin/gitlab-rake gitlab:backup:create CRON=1',
        user    => 'root',
        hour    => 2,
        minute  => 0,
    }

    # The private key for the certificate used by Nginx
    # The public part is distributed using Cosmos.
    sunet::snippets::secret_file { '/etc/gitlab/ssl/gitlab.nordu.net.key':
        hiera_key => 'gitlab_nordu_net_key'
    } ->

    # The SSH host-keys used by Gitlab for SSH-based git access.
    # The public part is distributed using Cosmos. 
    sunet::snippets::secret_file { '/etc/gitlab/ssh_host_rsa_key':
        hiera_key => 'ssh_host_rsa_key'
    } ->
    sunet::snippets::secret_file { '/etc/gitlab/ssh_host_ed25519_key':
        hiera_key => 'ssh_host_ed25519_key'
    } ->
    sunet::snippets::secret_file { '/etc/gitlab/ssh_host_ecdsa_key':
        hiera_key => 'ssh_host_ecdsa_key'
    } ->

    file { '/etc/gitlab/gitlab.rb':
        ensure  => file,
        path    => '/etc/gitlab/gitlab.rb',
        mode    => '0640',
        content => template('sunet/gitlab/gitlab_rb.erb'),
    } ->

    sunet::docker_run { 'gitlab':
        image    => 'gitlab/gitlab-ce',
        imagetag => 'latest',
        volumes  => ['/etc/gitlab:/etc/gitlab','/var/log/gitlab:/var/log/gitlab','/var/opt/gitlab:/var/opt/gitlab'],
        ports    => ['22:22','80:80','443:443'],
    }

}
