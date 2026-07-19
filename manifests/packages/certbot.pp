# certbot
class sunet::packages::certbot {
    package { 'certbot': ensure => installed }

    file { [
    '/etc/letsencrypt/renewal-hooks',
    '/etc/letsencrypt/renewal-hooks/deploy',
    ]:
      ensure  => directory,
      require => Package['certbot'],
    }
}
