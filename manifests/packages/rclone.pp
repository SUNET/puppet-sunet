class sunet::packages::rclone {

  $rclone_url = 'https://downloads.rclone.org/rclone-current-linux-amd64.deb'
  $rclone_local_path = '/tmp/rclone-current-linux-amd64.deb'

  exec { 'rclone_deb':
    command => "/usr/bin/wget -q ${rclone_url} -O ${rclone_local_path}",
    creates => $rclone_local_path,
  }
  package { 'rclone':
    ensure   => installed,
    provider => dpkg,
    source   => $rclone_local_path,
    require  => Exec['rclone_deb'],
  }
}
