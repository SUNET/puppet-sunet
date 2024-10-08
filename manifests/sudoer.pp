define sunet::sudoer($user_name = undef, $command_line = undef, $collection = undef) {
  $file = $collection ? {
    undef   => $name,
    default => $collection
  }
  ensure_resource('concat',"/etc/sudoers.d/${file}",{
    owner   => 'root',
    group   => 'root',
    mode    => '0440'
  })
  concat::fragment {"sudoer_${file}_${name}":
    target  => "/etc/sudoers.d/${file}",
    content => template('sunet/sudoers/sudoer.erb'),
    order   => '30'
  }
}
