# kopia repository
define sunet::kopia::repository(
  String $repository_name,
  String $remote_path,
  String $config_file,
){
  include sunet::package::kopia
  include sunet::package::rclone

  $dir = '/opt/kopia/repositories'
  exec { 'kopia_repository_dir':
    cmd    => "mkdir -p ${dir}",
    unless => "test -d ${dir}",
  }
  $repo_dir = "${dir}/${repository_name}"
  file { $repo_dir:
    ensure  => 'directory',
  }


  $password = lookup("kopia_repo_password_${repository_name}", undef, undef, 'NOT_SET_IN_HIERA')

  if ($password != 'NOT_SET_IN_HIERA') {
    exec { 'kopia_repository_create':
      command => "kopia repository create rclone --no-check-for-updates --password=${password} \
      --config-file=${config_file} --remote-path=${remote_path} --log-dir=${repo_dir} --create-only",
      unless  => "kopia repository status --config-file=${config_file}",
    }
  }
}
