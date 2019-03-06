class sunet::cgit(
  String $package       = 'cgit',
  String $cgitrepo_path = '/home/git/repositories/',
) {
  # So puppet-apply can't seem to find this resource.
  # Do this from cosmos-rules.yaml for now.
  #sunet::cgit::webserver { 'apache2': }

  package {$package: ensure => 'installed' }

  file { '/etc/cgitrc':
    content => template('cgit/cgitrc.erb'),
  }
}
