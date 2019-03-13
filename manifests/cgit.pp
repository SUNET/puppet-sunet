class sunet::cgit(
  String $package       = 'cgit',
  String $cgitrepo_path = '/home/git/repositories/',
) {
  sunet::cgit::webserver{'webserver for cgit':}

  file { '/etc/cgitrc':
    content => template('sunet/cgit/cgitrc.erb'),
  }
}
