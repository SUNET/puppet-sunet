# SUNET Inventory Service
class sunet::invent::client(
  String                         $invent_dir            = '/opt/invent',
  Variant[String, Array[String]] $export_endpoint       = [],
  String                         $facts_path            = '/etc/facter/facts.d',
  Integer[0]                     $invent_retention_days = 30,
  String                         $repo_path             = '/var/cache/invent/repo',
  String                         $repo_url              = 'https://github.com/SUNET/invent.git',
  Array[Pattern[/^[a-z_][a-z0-9_-]*$/]] $podman_users  = [],
) {
  $host_os = downcase($facts['os']['name'])

  include sunet::packages::curl
  include sunet::packages::git
  include sunet::packages::jq
  include sunet::packages::python3_yaml

  exec { 'create_repo_path':
    command => ['/usr/bin/mkdir', '-p', $repo_path],
    creates => $repo_path,
  }
  exec { 'clone_invent_repo':
    command => ['/usr/bin/git', 'clone', '--', $repo_url, $repo_path],
    creates => "${repo_path}/.git",
    require => [Exec['create_repo_path'], Class['sunet::packages::git']],
  }
  exec { 'update_invent_repo':
    command => '/usr/bin/git pull --ff-only',
    cwd     => $repo_path,
    unless  => '/usr/bin/git fetch --quiet && /usr/bin/git merge-base --is-ancestor @{upstream} HEAD',
    require => Exec['clone_invent_repo'],
  }
  file { '/etc/default/invent-client':
    ensure  => file,
    mode    => '0644',
    content => template('sunet/invent/invent-client.erb'),
  }
  exec { 'create_facts_path':
    command => ['/usr/bin/mkdir', '-p', $facts_path],
    creates => $facts_path,
  }
  ['ssh', 'hiera'].each |$collector| {
    file { "${facts_path}/${collector}.py":
      ensure  => link,
      target  => "${repo_path}/client/${collector}.py",
      require => [Exec['create_facts_path'], Exec['update_invent_repo']],
    }
  }
  sunet::scriptherder::cronjob { 'inventory':
    cmd      => "${repo_path}/client/invent.sh",
    job_name => 'gather_inventory',
    minute   => '*/10',
    user     => 'root',
    require  => [
      Exec['update_invent_repo'],
      File['/etc/default/invent-client'],
      File["${facts_path}/ssh.py"],
      File["${facts_path}/hiera.py"],
    ],
  }
  # remove old script path to not get confused over what script is running
  file { "${invent_dir}/scripts":
    ensure => 'absent',
    force  => 'true',
  }
}
