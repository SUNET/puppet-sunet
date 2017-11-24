# Manage a user in an htpasswd file
define sunet::misc::htpasswd_user(
  String $password,
  String $filename,
  String $user  = '',
  String $group = 'root',
) {
  package{'apache2-utils':
    ensure => installed,
  }

  $u = $user ? {
    ''      => $name,
    default => $user,
  }

  file { $filename:
    ensure => 'file',
    group  => $group,
    mode   => '0640',
  }

  if $password != 'NOT_SET_IN_HIERA' {
    exec { "htpasswd_user_${u}_${filename}":
      command => "htpasswd -b '${filename}' '${u}' '${password}'",
      path    => [ '/usr/bin', '/usr/sbin' ],
      require => File[$filename],
    }
  }
}
