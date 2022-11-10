# mastodon web server
class sunet::mastodon(
  $db_host                  = 'postgres',
  $db_name                  = 'mastodon',
  $db_port                  = '5432',
  $db_user                  = 'mastodon'
  $mastodon_version         = 'latest',
  $redis_host               = 'redis',
  $redis_port               = '6739',
  $s3_bucket                = 'mastodon',
  $s3_hostname              = 's3.sto3.safedc.net',
  $s3_port                  = '443',
  $saml_idp_sso_target_url  = '',
  $smtp_auth_method         = 'login',
  $smtp_ip                  = '192.36.171.214',
  $smtp_openssl_verify_mode = 'none',
  $smtp_port                = '465',
  $smtp_server              = 'smtp.sunet.se',
  $vhost                    = 'swehighered.sunet.se',
) {
  # Must set in hiera eyaml 
  $aws_access_key_id=safe_hiera('aws_access_key_id')
  $aws_secret_access_key=safe_hiera('aws_secret_access_key')
  $otp_secret=safe_hiera('otp_secret')
  $saml_cert=safe_hiera('saml_cert')
  $saml_idp_cert=safe_hiera('saml_idp_cert')
  $saml_private_key=safe_hiera('saml_private_key')
  $smtp_password=safe_hiera('smtp_password')
  $vaipd_public_key=safe_hiera('vaipd_public_key')
  $vapid_private_key=safe_hiera('vapid_private_key')
  $secret_key_base=safe_hiera('secret_key_base')

  # Interpolated variables
  $s3_alias_host = "${s3_hostname}:${s3_port}/${s3_bucket}"
  $s3_endpoint = "https://${s3_hostname}:${s3_port}"
  $smtp_from_address = "admin@${vhost}"
  $smtp_login = $smtp_from_address

  # Composefile
  sunet::docker_compose { 'mastodon':
    content          => template('sunet/mastodon/docker-compose.yml.erb'),
    service_name     => 'mastodon',
    compose_dir      => '/opt',
    compose_filename => 'docker-compose.yml',
    description      => 'Mastodon',
  }
  # Directories and files
  -> file { '/opt/mastodon/mastodon.env':
    ensure  => file,
    owner   => 'root',
    group   => 'root',
    mode    => '0640',
    content => template('sunet/mastodon/mastodon.env.erb'),
  }
  $tl_dirs = ['mastodon', 'nginx', 'postgres', 'redis']
  $tl_dirs.each | $dir| {
    file { "/opt/mastodon/${dir}":
      ensure => directory,
      owner  => 'root',
      group  => 'root',
      mode   => '0751',
    }
  }
  $nginx_dirs = ['acme', 'certs', 'conf', 'dhparam', 'html', 'vhost']
  $nginx_dirs.each | $dir| {
    file { "/opt/mastodon/nginx/${dir}":
      ensure => directory,
      owner  => 'root',
      group  => 'root',
      mode   => '0751',
    }
  }
}
