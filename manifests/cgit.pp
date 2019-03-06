class sunet::cgit(
  String $package       = 'cgit',
  String $cgitrepo_path = '/home/git/repositories/',
) {
  sunet::cgit::webserver { 'apache2': }

  package {$package: ensure => 'installed' }

  file { '/etc/cgitrc':
    content => template('cgit/cgitrc.erb'),
  }
}
