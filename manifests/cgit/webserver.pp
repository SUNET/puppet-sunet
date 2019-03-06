class sunet::cgit::webserver(
  String $service = 'apache2',
  String $package = 'apache2',
  String $www_user = 'www-data',
  String $git_group = 'git',
) {
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
