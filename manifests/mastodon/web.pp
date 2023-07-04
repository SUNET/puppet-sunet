# mastodon web server
class sunet::mastodon::web(
  String $db_host                  = 'postgres',
  String $db_name                  = 'postgres',
  String $db_port                  = '5432',
  String $db_user                  = 'postgres',
  String $interface                = 'ens3',
  String $mastodon_version         = 'latest',
  String $redis_host               = 'redis',
  String $redis_port               = '6379',
  String $redis_user               = 'admin',
  String $s3_bucket                = 'mastodon',
  String $s3_alias_path            = '/swift/v1/f7ddf8916b054d22a4b8245e1df640ea',
  String $s3_hostname              = 's3.sto3.safedc.net',
  String $s3_port                  = '443',
  String $saml_idp_sso_target_url  = 'https://idp-proxy-social.sunet.se/idp/sso',
  String $smtp_auth_method         = 'login',
  String $smtp_ip                  = '192.36.171.214',
  String $smtp_openssl_verify_mode = 'none',
  String $smtp_port                = '587',
  String $smtp_server              = 'smtp.sunet.se',
  String $vhost                    = 'social.sunet.se',
) {
  # Must set in hiera eyaml
  $aws_access_key_id=safe_hiera('aws_access_key_id')
  $aws_secret_access_key=safe_hiera('aws_secret_access_key')
  $db_pass=safe_hiera('db_pass')
  $otp_secret=safe_hiera('otp_secret')
  $redis_pass=safe_hiera('redis_pass')
  $s3_alias_host = safe_hiera('s3_alias_host')
  $saml_cert=safe_hiera('saml_cert')
  $saml_idp_cert=safe_hiera('saml_idp_cert')
  $saml_private_key=safe_hiera('saml_private_key')
  $secret_key_base=safe_hiera('secret_key_base')
  $smtp_password=safe_hiera('smtp_password')
  $vaipd_public_key=safe_hiera('vaipd_public_key')
  $vapid_private_key=safe_hiera('vapid_private_key')

  # Interpolated variables
  $s3_endpoint = "https://${s3_hostname}:${s3_port}"
  $temp_array = split($vhost, '[.]')
  $smtp_user = $temp_array[0]
  $smtp_from_address = "${smtp_user}@sunet.se"
  $smtp_login = $smtp_user

  # Composefile
  sunet::docker_compose { 'mastodon_web':
    content          => template('sunet/mastodon/web/docker-compose.yml.erb'),
    service_name     => 'mastodon_web',
    compose_dir      => '/opt',
    compose_filename => 'docker-compose.yml',
    description      => 'Mastodon',
  }
  # Directories and files
  -> file { '/opt/mastodon_web/mastodon.env':
    ensure  => file,
    owner   => 'root',
    group   => 'root',
    mode    => '0640',
    content => template('sunet/mastodon/web/mastodon.env.erb'),
  }
  -> file { '/opt/mastodon_web/files-nginx-vhost.conf':
    ensure  => file,
    owner   => 'root',
    group   => 'root',
    mode    => '0640',
    content => template('sunet/mastodon/web/files-nginx-vhost.conf.erb'),
  }
  -> file { '/usr/local/bin/tootctl':
    ensure  => file,
    owner   => 'root',
    group   => 'root',
    mode    => '0750',
    content => template('sunet/mastodon/web/tootctl.erb.sh'),
  }
  $tl_dirs = ['mastodon', 'nginx']
  $tl_dirs.each | $dir| {
    file { "/opt/mastodon_web/${dir}":
      ensure => directory,
      owner  => 'root',
      group  => 'root',
      mode   => '0751',
    }
  }
  $nginx_dirs = ['acme', 'certs', 'conf', 'dhparam', 'html', 'vhost']
  $nginx_dirs.each | $dir| {
    file { "/opt/mastodon_web/nginx/${dir}":
      ensure => directory,
      owner  => 'root',
      group  => 'root',
      mode   => '0751',
    }
  }

  if $::facts['sunet_nftables_enabled'] == 'yes' {
    sunet::nftables::docker_expose { 'web_http_port' :
      iif           => $interface,
      allow_clients => 'any',
      port          => 80,
    }
    sunet::nftables::docker_expose { 'web_https_port' :
      iif           => $interface,
      allow_clients => 'any',
      port          => 443,
    }
  } else {
    sunet::misc::ufw_allow { 'web_ports':
      from => 'any',
      port => ['80', '443']
    }
  }
}
