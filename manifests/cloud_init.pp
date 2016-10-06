class sunet::cloud_init {
   exec { 'update-cloud-init':
      command      => 'dpkg-reconfigure -f noninteractive cloud-init',
      refresh_only => true
   }
}

define sunet::cloud_init::config ($prio = "99", $config = {}) {
   ensure_resource ('class','sunet::cloud_init', { })
   file { "/etc/cloud/cloud.cfg.d/$prio_$title.cfg":
      owner   => root,
      group   => root,
      content => inline_template("---\n<%= @config.to_yaml %>"),
      notify  => Exec['update-cloud-init']
   }
}
