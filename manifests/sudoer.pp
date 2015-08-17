include stdlib
include concat

define sunet::sudoer($user_name = undef, $command_line = undef, $tag = undef) {
  $collection = $tag ? {
    undef   => $name,
    default => $sudoers
  }
  ensure_resource('concat',"/etc/sudoers.d/${collection}",{
    owner   => 'root',
    group   => 'root',
    mode    => '0440' 
  })
  concat::fragment {"sudoer_${collction}_${name}":
    target  => "/etc/sudoers.d/${collection}",
    content => template('sunet/sudoers/sudoer.erb'),
    order   => '30'
  }
}
