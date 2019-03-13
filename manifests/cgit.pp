class sunet::cgit(
  String $fqdn,
  String $package       = 'cgit',
  String $cgitrepo_path = '/home/git/repositories/',
  String $www_user      = 'www-data',
  String $git_group     = 'git',
) {
  exec { 'let web user read git repos':
    command => "adduser $www_user $git_group",
  }

  exec { 'enable CGI':
    command => 'a2enmod cgid',
    creates => '/etc/apache2/mods-enabled/cgid.conf',
    notify  => Service['apache2'],
  }

  file { '/etc/cgitrc':
    content => template('sunet/cgit/cgitrc.erb'),
  }

  file { '/etc/apache2/sites-available/010-cgit':
    template => 'sunet/cgit/apache2-siteconf.erb',
  }

  exec { '/etc/apache2/sites-enabled/010-cgit.conf':
    command => 'a2ensite 010-cgit',
    creates => $name,
    onlyif  => 'test -s /etc/ssl/certs/git.sunet.se.crt',
    notify  => Service['apache2'],
  }
}
