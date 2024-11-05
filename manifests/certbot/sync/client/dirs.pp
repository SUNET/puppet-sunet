# the certbot sync client dirs
class sunet::certbot::sync::client::dirs(
){
  file { '/opt/certbot-sync':
    ensure => directory,
    mode   => '0700',
  }
  file { '/opt/certbot-sync/libexec':
    ensure => directory,
    mode   => '0700',
  }
  file { '/opt/certbot-sync/letsencrypt':
    ensure => directory,
    mode   => '0700',
  }
  file { '/opt/certbot-sync/renewal-hooks':
    ensure => directory,
    mode   => '0700',
  }
  file { '/opt/certbot-sync/renewal-hooks/deploy':
    ensure => directory,
    mode   => '0700',
  }
}
