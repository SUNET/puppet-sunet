define sunet::telegraf::plugin($plugin=undef,$config=undef) {
  if (defined(Service['telegraf'])) {
      $_plugin = $plugin ? {
        undef   => $title,
        default => $plugin
      }
      $params = $config ? {
        undef   => lookup("telegraf_plugin_${title}", undef, undef, {}),
        default => $config
      }
      file { "/etc/telegraf/telegraf.d/${_plugin}.conf":
        ensure  => file,
        content => epp("sunet/telegraf/plugins/${_plugin}-conf.epp",$params),
        notify  => Service['telegraf']
      }
  }
}
