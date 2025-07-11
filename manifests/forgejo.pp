# A class to install and manage Forgejo
class sunet::forgejo (
  String $domain          = 'platform.sunet.se',
  String $interface       = 'ens3',
  String $forgejo_version = '1.18.5-0-rootless',
  Integer $uid            = '900',
  Integer $gid            = '900',
) {
  include sunet::packages::rclone
  package { 'duplicity':
    ensure => latest,
  }
  # gitea generate secret INTERNAL_TOKEN
  $internal_token = lookup('internal_token', undef, undef, undef)
  # gitea generate secret JWT_SECRET
  $jwt_secret = lookup('jwt_secret', undef, undef, undef)
  # gitea generate secret JWT_SECRET
  $lfs_jwt_secret = lookup('lfs_jwt_secret', undef, undef, undef)
  # gitea generate secret SECRET_KEY
  $secret_key = lookup('secret_key', undef, undef, undef)
  # SMTP Password from NOC
  $smtp_user = split($domain, '[.]')[0]
  $smtp_password = lookup('smtp_password', undef, undef, undef)

  # S3 credentials from openstack
  $s3_secret_key = lookup('s3_secret_key', undef, undef, undef)
  $s3_access_key = lookup('s3_access_key', undef, undef, undef)
  $s3_host = 's3.sto4.safedc.net'

  # GPG password
  $platform_sunet_se_gpg_password = lookup('platform_sunet_se_gpg_password', undef, undef, undef)

  # GPG key
  $platform_sunet_se_gpg_key = lookup('platform_sunet_se_gpg_key', undef, undef, undef)

  # Nginx stuff
  file{ '/opt/nginx':
    ensure => directory,
  }
  $nginx_dirs = ['conf', 'dhparam', 'html', 'vhost', 'template']
  $nginx_dirs.each|$dir| {
    file{ "/opt/nginx/${dir}":
      ensure => directory,
    }
  }
  file{ '/opt/nginx/template/nginx.tmpl':
    ensure  => file,
    content => template('sunet/forgejo/nginx.tmpl'),
    mode    => '0644',
  }
  # Compose
  sunet::docker_compose { 'forgejo':
    content          => template('sunet/forgejo/docker-compose.yaml.erb'),
    service_name     => 'forgejo',
    compose_dir      => '/opt',
    compose_filename => 'docker-compose.yaml',
    description      => 'Forgejo Git Services',
  }
  -> sunet::misc::system_user { 'git':
    group => 'git',
    uid   => $uid,
    gid   => $gid,
  }
  # Data directory
  -> file{ '/opt/forgejo/data':
    ensure => directory,
    owner  => 'git',
    group  => 'git',
  }
  # Config directory/file
  -> file{ '/opt/forgejo/config':
    ensure => directory,
    owner  => 'git',
    group  => 'git',
  }
  -> file{ '/opt/forgejo/backups':
    ensure => directory,
    owner  => 'git',
    group  => 'git',
  }
  -> file{ '/opt/forgejo/config/app.ini':
    ensure  => file,
    content => template('sunet/forgejo/app.ini.erb'),
    mode    => '0644',
    owner   => 'git',
    group   => 'git',
  }
  -> file { '/etc/systemd/system/sunet-forgejo.service.d':
    ensure => directory,
    owner  => 'root',
    group  => 'root',
    mode   => '0755',
  }
  -> file { '/etc/systemd/system/sunet-forgejo.service.d/01-execstartpost.conf':
    ensure  => file,
    owner   => 'root',
    group   => 'root',
    mode    => '0744',
    content => "[Service]
ExecStartPost=/bin/bash -c 'until docker inspect forgejo | jq .[0].State.Running | grep true ; do sleep 1 && echo -n . ; done'
ExecStartPost=/usr/bin/docker compose -f /opt/forgejo/docker-compose.yaml exec -d forgejo mkdir -p /tmp/gitea\n",
  }
  -> exec { 'forgejo_daemonreload_execstartpost':
  subscribe   => File['/etc/systemd/system/sunet-forgejo.service.d/01-execstartpost.conf'],
  command     => 'systemctl daemon-reload',
  refreshonly => true,
  }
  -> exec { 'forgejo_override_execstartpost':
  subscribe   => File['/etc/systemd/system/sunet-forgejo.service.d/01-execstartpost.conf'],
  command     => 'systemctl restart sunet-forgejo.service',
  refreshonly => true,
  onlyif      => 'systemctl is-active sunet-forgejo.service',
  }
  -> file{ '/root/.rclone.conf':
    ensure  => file,
    content => template('sunet/forgejo/rclone.conf.erb'),
    mode    => '0644',
  }
  -> file{ '/opt/forgejo/backup.sh':
    ensure  => file,
    content => template('sunet/forgejo/backup.erb.sh'),
    mode    => '0744',
  }
  -> sunet::scriptherder::cronjob { 'forgejo_backup':
    cmd           => '/opt/forgejo/backup.sh',
    minute        => '20',
    hour          => '*/2',
    ok_criteria   => ['exit_status=0', 'max_age=3h'],
    warn_criteria => ['exit_status=0', 'max_age=5h'],
  }

  if $::facts['sunet_nftables_enabled'] == 'yes' {
    sunet::nftables::docker_expose { 'forgejo_80_port' :
      iif           => $interface,
      allow_clients => 'any',
      port          => 80,
    }
    sunet::nftables::docker_expose { 'forgejo_443_port' :
      iif           => $interface,
      allow_clients => 'any',
      port          => 443,
    }
    sunet::nftables::docker_expose { 'forgejo_22022_port' :
      iif           => $interface,
      allow_clients => 'any',
      port          => 22022,
    }
  } else {
    sunet::misc::ufw_allow { 'forgejo_ports':
      from => 'any',
      port => ['80', '443', '22022'],
    }
  }
  file{ '/opt/forgejo/import-secret-key.sh':
    ensure  => file,
    content => template('sunet/forgejo/import-secret-key.erb.sh'),
    mode    => '0700',
  }
  # Import gpg key
  -> exec{ 'import_gpg_key':
    command => '/opt/forgejo/import-secret-key.sh'
  }
}
