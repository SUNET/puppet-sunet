define sunet::telegraf::plugin($config=undef) {
   $params = $config ? {
      undef   => hiera("telegraf_plugin_$title",{}),
      default => $config
   }
   file { "/etc/telegraf/telegraf.d/$title.conf": 
      ensure  => file,
      content => template("sunet/telegraf/plugins/$title-conf.erb")
      notify  => Service['telegraf']
   }
}
