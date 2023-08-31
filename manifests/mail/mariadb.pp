# Sunet mail db class
class sunet::mail::mariadb () {
  $postfix_password = safe_hiera('postfix_password')
  $sogo_password = safe_hiera('sogo_password')
  file { '/opt/mariadb/':
    ensure  => directory,
  }
  file { '/opt/mariadb/init/':
    ensure  => directory,
  }
  file { '/opt/mariadb/init/03mail.sql':
    ensure  => file,
    content => template('sunet/mail/mariadb/03mail.erb.sql')
  }
  file { '/opt/mariadb/init/04sogo.sql':
    ensure  => file,
    content => template('sunet/mail/mariadb/04sogo.erb.sql')
  }
}
