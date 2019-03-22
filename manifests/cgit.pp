class sunet::cgit(
  String $fqdn,
  String $public_hostname,
  String $package         = 'cgit',
  String $cgitrepo_path   = '/home/git/repositories/',
  String $cgit_logo       = '',
  String $www_user        = 'www-data',
  String $git_group       = 'git',
) {
  exec { 'let web user read git repos':
    command => "adduser $www_user $git_group",
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

  file { '/etc/cgitrc':
    content => template('sunet/cgit/cgitrc.erb'),
  }

  file { '/etc/apache2/sites-available/010-cgit.conf':
    content => template('sunet/cgit/apache2-siteconf.erb'),
  }

  exec { 'enable 010-cgit':
    command => 'a2ensite 010-cgit',
    creates => '/etc/apache2/sites-enabled/010-cgit.conf',
    onlyif  => 'test -s /etc/ssl/certs/git-prod-1.sunet.se.crt',
    notify  => Service['apache2'],
  }
}
