# cgit
class sunet::cgit(
    String  $fqdn,
    String  $public_hostname,
    String  $package         = 'cgit',
    String  $cgitrepo_path   = '/home/git/repositories',
    String  $cgit_logo       = '',
    String  $root_title      = 'Default title',
    String  $root_desc       = 'Default description',
    String  $www_user        = 'www-data',
    String  $git_group       = 'git',
    Boolean $disallow_robots = true,
) {
    # How to configure access to repositories with cgit and gitolite:
    #
    # In gitolite-admin/conf/gitolite.conf:
    # If you set R = daemon then the Git daemon provides unauthenticated access
    # to the repository without any transport encryption using git://.
    # This will also  make the repository visible on https://your-site.tld and
    # therefore make it possible to also clone using HTTPS.
    # Please observe that allocating any rights to "gitweb" is a no-op and has
    # no meaning for the current configuration of cgit.
    #
    # cgit configuration:
    # If you want to provide unauthenticated access using git://, i.e. with any
    # transport encryption, but hide the repo on https://your-site.tld, you can
    # put an cgitrc file in the bare repo with following content, which will make
    # cgit completely ignore the repo:
    # ignore=1
    #
    # To only make cgit hide the repo so that you can still clone it using HTTPS
    # and view it on https://git.sunet.se if providing the correct path, add the
    # follwing to a cgitrc file in the bare repo:
    # hide=1

    package { $package: ensure => latest }

    -> exec { 'let web user read git repos':
        command => "adduser ${www_user} ${git_group}",
    }

    exec { 'disable status module':
        command => 'a2dismod status',
        onlyif  => 'test -L /etc/apache2/mods-enabled/status.conf',
        notify  => Service['apache2'],
    }

    exec { 'disable 000-default':
        command => 'a2dissite 000-default',
        onlyif  => 'test -L /etc/apache2/sites-enabled/000-default.conf',
        notify  => Service['apache2'],
    }

    exec { 'disable default cgit configuration':
        command => 'a2disconf cgit',
        onlyif  => 'test -L /etc/apache2/conf-enabled/cgit.conf',
        notify  => Service['apache2'],
    }

    exec { 'enable CGI':
        command => 'a2enmod cgid',
        creates => '/etc/apache2/mods-enabled/cgid.load',
        notify  => Service['apache2'],
    }

    exec { 'enable HTTP2':
        command => 'a2enmod http2',
        creates => '/etc/apache2/mods-enabled/http2.load',
        notify  => Service['apache2'],
    }

    exec { 'enable headers':
        command => 'a2enmod headers',
        creates => '/etc/apache2/mods-enabled/headers.load',
        notify  => Service['apache2'],
    }

    file { '/etc/cgitrc':
        content => template('sunet/cgit/cgitrc.erb'),
    }

    file { '/etc/apache2/sites-available/010-cgit.conf':
        content => template('sunet/cgit/apache2-siteconf.erb'),
    }

    if $disallow_robots {
      file { '/var/www/html/robots.txt':
          content => file('sunet/cgit/robots.txt'),
      }
    }

    exec { 'enable 010-cgit':
        command => 'a2ensite 010-cgit',
        creates => '/etc/apache2/sites-enabled/010-cgit.conf',
        onlyif  => "test -s /etc/ssl/certs/${fqdn}.crt",
        notify  => Service['apache2'],
    }

    # To avoid a duplicated declaration with other manifests
    # such as unbound.pp etc, exec instead of file is used here.
    exec { 'cgit_apparmor_dir':
        command => 'mkdir -p /etc/apparmor-cosmos',
        unless  => 'test -d /etc/apparmor-cosmos',
    }
    -> file { '/etc/apparmor-cosmos/usr.lib.cgit.cgit.cgi':
        ensure  => 'file',
        owner   => 'root',
        group   => 'root',
        content => template('sunet/cgit/usr.lib.cgit.cgit.cgi.erb'),
    }

    apparmor::profile { 'usr.lib.cgit.cgit.cgi':
        source => '/etc/apparmor-cosmos/usr.lib.cgit.cgit.cgi',
    }

}
