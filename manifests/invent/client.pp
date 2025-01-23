# SUNET Inventory Service
class sunet::invent::client(
  String  $invent_dir            = '/opt/invent',
  String  $export_endpoint       = '',
  Integer $invent_retention_days = 30,
  String  $repo_path             = '/var/cache/invent/repo',
  String  $repo_url              = 'https://github.com/SUNET/invent.git',
) {
  $host_os = String($facts['os']['name'], '%d')

  include sunet::packages::curl
  include sunet::packages::git
  include sunet::packages::jq

  exec {'create_repo_path':
    command => "mkdir -p ${repo_path}",
    unless  =>  "test -d ${repo_path}",
  }
  exec { 'clone_invent_repo':
    command => "git clone ${repo_url} ${repo_path}",
    unless  => "test -d ${repo_path}/.git"
  }
  exec { 'update_invent_repo':
    command => "sh -c 'cd ${repo_path} && git pull'"
  }
  file { '/etc/default/invent-client':
    ensure  => 'file',
    mode    => '0644',
    content => template('sunet/invent/invent-client.erb'),
  }
  sunet::scriptherder::cronjob { 'inventory':
    cmd         => "${repo_path}/client/invent.sh",
    job_name    => 'gather_inventory',
    minute      => '*/10',
    user        => 'root',
  }
  # remove old script path to not get confused over what script is running
  file { "${invent_dir}/scripts":
    ensure => 'absent',
    force  => 'true',
  }
}
