class sunet::cgit(
  String $package       = 'cgit',
  String $cgitrepo_path = '/home/git/repositories/',
) {
  include sunet::cgit::webserver

  package {$package: ensure => 'installed' }

  file { '/etc/cgitrc':
    content => template('cgit/cgitrc.erb'),
  }
}
