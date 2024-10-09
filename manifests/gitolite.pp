# gitolite
class sunet::gitolite(
    $username                         = 'git',
    $group                            = 'git',
    $ssh_key                          = undef,
    $enable_git_daemon                = false,
    $save_private_admin_key_on_server = true,
    $use_apparmor                     = false,
    $cgit_custom_config               = false,
) {
    ensure_resource('sunet::system_user', $username, {
        username   => $username,
        group      => $group,
        managehome => true,
        shell      => '/bin/bash'
    })

    $hostname = $facts['networking']['fqdn']
    $shortname = $facts['networking']['hostname']

    $home = $username ? {
        'root'    => '/root',
        default   => "/home/${username}"
    }

    $_ssh_key = $ssh_key ? {
        undef   => lookup('gitolite-admin-ssh-key', undef, undef, undef),
        ''      => lookup('gitolite-admin-ssh-key', undef, undef, undef),
        default => $ssh_key
    }

    file { ["${home}/.gitolite","${home}/.gitolite/logs"]:
        ensure => directory,
        owner  => $username,
        group  => $group
    }

    -> if $save_private_admin_key_on_server {
        case $_ssh_key {
            undef: {
                sunet::snippets::ssh_keygen { "${home}/admin": }
            }
            default: {
                file { "${home}/admin":
                    ensure  => file,
                    mode    => '0600',
                    owner   => 'root',
                    group   => 'root',
                    content => inline_template('<%= @_ssh_key %>'),
                }
                sunet::snippets::ssh_pubkey_from_privkey { "${home}/admin": }
            }
        }
    } elsif $save_private_admin_key_on_server == false {
        $gitolite_initial_public_admin_key = lookup('gitolite-initial-public-admin-key', undef, undef, undef)
        file { "${home}/admin.pub":
            ensure  => file,
            owner   => 'root',
            group   => 'root',
            content => inline_template('<%= @gitolite_initial_public_admin_key %>'),
        }
    }

    package {'gitolite3': ensure => latest }
    -> file { "${home}/.gitolite.rc":
        ensure  => file,
        owner   => $username,
        group   => $group,
        content => template('sunet/gitolite/gitolite-rc.erb'),
    }

    -> exec {'gitolite-setup':
        command     => "gitolite setup -pk ${home}/admin.pub",
        user        => $username,
        environment => ["HOME=${home}"]
    }

    if $enable_git_daemon {
        package { 'git-daemon-sysvinit':
            ensure => latest
        }
        -> file { '/etc/default/git-daemon':
            ensure  => file,
            owner   => 'root',
            group   => 'root',
            content => template('sunet/gitolite/git-daemon.erb'),
        }
        -> sunet::snippets::add_user_to_group { 'git_daemon_repository_access':
            username => 'gitdaemon',
            group    => $group,
        }
        sunet::misc::ufw_allow { 'allow-git-daemon':
            from => 'any',
            port => '9418',
        }
    }

    if $use_apparmor {
        # To avoid a duplicated declaration with other manifests
        # such as unbound.pp etc, exec instead of file is used here.
        exec { 'gitolite_apparmor_dir':
            command => 'mkdir -p /etc/apparmor-cosmos',
            unless  => 'test -d /etc/apparmor-cosmos',
        }
        -> file { '/etc/apparmor-cosmos/usr.share.gitolite3.gitolite-shell':
            ensure  => 'file',
            owner   => 'root',
            group   => 'root',
            content => template('sunet/gitolite/usr.share.gitolite3.gitolite-shell.erb'),
        }
        file { '/etc/apparmor-cosmos/usr.lib.git-core.git-daemon':
            ensure  => 'file',
            owner   => 'root',
            group   => 'root',
            content => template('sunet/gitolite/usr.lib.git-core.git-daemon.erb'),
        }

        apparmor::profile { 'usr.share.gitolite3.gitolite-shell':
            source => '/etc/apparmor-cosmos/usr.share.gitolite3.gitolite-shell',
        }
        apparmor::profile { 'usr.lib.git-core.git-daemon':
            source => '/etc/apparmor-cosmos/usr.lib.git-core.git-daemon',
        }
    }
}
