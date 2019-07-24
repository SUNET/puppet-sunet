define sunet::telegraf::plugin($config=undef) {
   $params = $config ? {
      undef   => hiera("telegraf_plugin_$title",{}),
      default => $config
   }
   file { "/etc/telegraf/telegraf.d/$title.conf": 
      ensure  => file,
      content => epp("sunet/telegraf/plugins/$title-conf.epp",$params),
      notify  => Service['telegraf']
   }
}
