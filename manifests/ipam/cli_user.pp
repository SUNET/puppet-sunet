# Creation of local user accounts to use nipap cli is configured through below defined type.

define sunet::ipam::cli_user(
    String $username,
    String $name_of_user,
  ) {
    # Below creates a password for each of the user added in nipap's authentication database.
    $password = chomp (generate ('/usr/bin/pwgen', '-1'))
    # Creates a sytem user in the host.
    user { $username:
      ensure   => present,
      password => '*',
      home     => "/home/${username}",
    }
    # Creates a home directory for the system user.
    -> file { "/home/${username}":
        ensure => directory,
        owner  => $username,
        group  => $username,
        }
    # Follwoing two resources create local users account to use the nipap cli.
    -> exec { "create_${username}_local_user":
        command => "nipap-passwd add --username ${username} --password ${password} --name '${name_of_user}'",
        unless  => "/usr/sbin/nipap-passwd list | grep ${username}",
        require => Package['nipapd'],
        }
    -> file { "/home/${username}/.nipaprc":
        ensure  => file,
        owner   => $username,
        group   => $username,
        mode    => '0600',
        content => template('sunet/ipam/.nipaprc.erb'),
        replace => false,
        }
    }
