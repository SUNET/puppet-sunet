# A class to install and manage Forgejo
class sunet::forgejo (
  String $domain          = 'platform.sunet.se',
  String $forgejo_version = '1.18.5-0-rootless',
  Integer $uid            = '900',
  Integer $gid            = '900',
) {
  include sunet::packages::rclone
  package { 'duplicity':
    ensure => latest,
  }
  docker_network { 'docker':
    ensure => 'present',
  }
  sunet::docker_run {'alwayshttps':
    ensure => 'present',
    image  => 'docker.sunet.se/always-https',
    ports  => ['80:80'],
    env    => ['ACME_URL=http://acme-c.sunet.se'],
  }
  # gitea generate secret INTERNAL_TOKEN
  $internal_token = hiera('internal_token')
  # gitea generate secret JWT_SECRET
  $jwt_secret = hiera('jwt_secret')
  # gitea generate secret JWT_SECRET
  $lfs_jwt_secret = hiera('lfs_jwt_secret')
  # gitea generate secret SECRET_KEY
  $secret_key = hiera('secret_key')
  # SMTP Password from NOC
  $smtp_password = hiera('smtp_password')

  # S3 credentials from openstack
  $s3_secret_key = hiera('s3_secret_key')
  $s3_access_key = hiera('s3_access_key')
  $s3_host = 's3.sto4.safedc.net'

  # White list for email domains for account creation
  $email_domain_whitelist = hiera('email_domain_whitelist')
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
  -> sunet::misc::ufw_allow { 'forgejo_ports':
    from => 'any',
    port => ['80', '443', '22022'],
  }
}
