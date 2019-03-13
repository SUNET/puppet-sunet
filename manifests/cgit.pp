class sunet::cgit(
  String $package       = 'cgit',
  String $cgitrepo_path = '/home/git/repositories/',
  String $www_user  = 'www-data',
  String $git_group = 'git',
) {
  ensure_package(['apache2'])

  service { 'apache2':
    ensure  => 'running',
    enable  => true,
    require => Package['apache2'],
  }

  exec { 'let web user read git repos':
    command => "adduser $www_user $git_group",
  }

  exec { 'enable CGI':
    command => 'a2enmod cgi',
    notify  => Service['apache2'],
  }

  file { '/etc/cgitrc':
    content => template('sunet/cgit/cgitrc.erb'),
  }
}
