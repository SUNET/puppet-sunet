# This is a custom type that will retrieve a file from a remote location
define sunet::remote_file($ensure=file, $remote_location=undef, $mode='0644'){
  if ($ensure != 'absent') {
    exec{"retrieve_${title}":
      command => "/usr/bin/wget -q ${remote_location} -O ${title}",
      creates => $title,
    }
  }

  file{$title:
    ensure  => $ensure,
    mode    => $mode,
    require => Exec["retrieve_${title}"],
  }
}
