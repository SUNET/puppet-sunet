# kopia repository
define sunet::kopia::repository(
  String $config_file,
  String $password,
  String $remote_path,
  String $repository_name,
){
  include sunet::packages::kopia

  $dir = '/opt/kopia/repositories'
  $repo_dir = "${dir}/${repository_name}"
  exec { "kopia_repository_create_${repository_name}":
    command => "kopia repository create rclone --no-check-for-updates --password=${password} \
    --config-file=${config_file} --remote-path=${remote_path} --log-dir=${repo_dir}",
  }
  exec { "kopia_repository_connect_${repository_name}":
    command => "kopia repository connect rclone --remote-path=${remote_path} --password=${password}  --config-file=${config_file}",
  }
}
