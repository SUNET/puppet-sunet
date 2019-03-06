class sunet::cgit::webserver(
  String $service = 'apache2',
  String $package = $service,
  String $www_user = 'www-data',
  String $git_group = 'git',
) {
  package { $package:
    ensure => 'installed'
  }

  service { "$service":
    ensure => 'running',
    enable => true,
    require => Package[$package],
  }

  exec { 'let web user read git repos':
    command => "adduser $www_user $git_group",
  }

  exec { 'enable CGI':
    command => 'a2enmod cgi',
    notify  => Service[$service],
  }
}
