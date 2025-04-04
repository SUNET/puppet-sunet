# Api frontend class and optiona docker image scanner
class sunet::invent::scanner(
  Boolean $install_docker_io = true,
  String  $image_path = '/var/cache/invent/images',
  String  $registry = 'docker.sunet.se',
  String  $registry_url = "https://${registry}",
  String  $repo_path = '/var/cache/invent/repo',
  String  $repo_url = 'https://github.com/SUNET/invent.git',
) {
  include sunet::packages::curl
  include sunet::packages::git
  include sunet::packages::jq
  if $install_docker_io {
    include sunet::packages::docker_io
  }
  exec {'create_repo_path_scanner':
    command => "mkdir -p ${repo_path}",
    unless  =>  "test -d ${repo_path}",
  }
  -> exec {'create_image_path':
    command => "mkdir -p ${image_path}",
    unless  =>  "test -d ${image_path}",
  }
  -> exec { 'clone_invent_repo_scanner':
    command => "git clone ${repo_url} ${repo_path}",
    unless  => "test -d ${repo_path}/.git"
  }
  -> exec { 'update_invent_repo_scanner':
    command => "sh -c 'cd ${repo_path} && git pull'"
  }
  -> file { '/usr/local/bin/scanner':
    ensure  => file,
    mode    => '0755',
    content => template('sunet/invent/scanner.erb.sh'),
  }
  -> sunet::scriptherder::cronjob { 'docker_repo_scanner':
    cmd    => '/usr/local/bin/scanner',
    hour   =>  '*/12',
    minute =>  '10',
  }

}
